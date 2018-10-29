#!/usr/bin/python3

import logging
import os
import re
import sys
import time

import boto3
from botocore.exceptions import ClientError


# get logger
logger = logging.getLogger('lambda-ebs-attach')
logger.setLevel(os.environ['LOG_LEVEL'].upper())

# ssm document name
SSM_DOCUMENT_NAME = os.environ['SSM_DOCUMENT_NAME']
SSM_ENABLED = os.environ['SSM_ENABLED'].lower() == "true"

# tag key identifying volumes we should look for
ASG_TAG = os.environ['ASG_TAG']

# get current region, it is in ENV by default
AWS_REGION = os.environ['AWS_DEFAULT_REGION']

# clients
ec2_client = boto3.client('ec2', region_name=AWS_REGION)
asg_client = boto3.client('autoscaling', region_name=AWS_REGION)
ssm_client = boto3.client('ssm', region_name=AWS_REGION)


class BadHTTPStatusCode(Exception):
    pass


class NoMatchingVolumesFound(Exception):
    pass


class MissingDeviceDefinition(Exception):
    pass


class MisformattedVolumeTag(Exception):
    pass


class MissingValueInVolumeTagKey(Exception):
    pass


class InvalidMountPoint(Exception):
    pass


class InvalidTagKeyFound(Exception):
    pass


class SsmCommandFailed(Exception):
    pass


def check_status_code(return_data):
    """
    Checks return_data['ResponseMetadata'] for correct HTTP code
    """

    if return_data['ResponseMetadata']['HTTPStatusCode'] != 200:
        raise BadHTTPStatusCode('ERROR: {}'.format(return_data['ResponseMetadata']))


def instance_data(instance_id):
    """
    Gets info about instance and retruns dicts containing instance's attributes
    """

    instance = ec2_client.describe_instances(InstanceIds=[instance_id])
    check_status_code(instance)

    return instance['Reservations'][0]['Instances'][0]


def parse_asg_tag(asg_name):
    """
    Parses ASG tag as specified by lambda's environment parameter.
    This tag is then used as a tag-key filter for finding EBS volumes.
    """

    asg_data = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
    check_status_code(asg_data)

    # get contents of ASG_TAG. It is coma delimited string containg EBS volumes' tag keys
    tags = asg_data['AutoScalingGroups'][0]['Tags']
    ebs_tag_keys = [tag['Value'].split(',') for tag in tags if tag['Key'] == ASG_TAG][0]

    return ebs_tag_keys


def parse_validate_volume_tag(tag):
        # example tag "device=xvdf,mountpoint=/app/data,label=DATA"
    try:
        tag_dict = dict(d.split('=') for d in tag.split(','))
    except IndexError:
        raise MisformattedVolumeTag('Error: {}'.format(tag))

    # check for any invalid keys
    for key in tag_dict:
        if key not in ('device', 'label', 'mountpoint'):
            raise InvalidTagKeyFound('Error: Allowed tag keys are "device", "label" and "mountpoint". Got {}'.format(tag))

    # device key is required
    if 'device' not in tag_dict:
        raise MissingDeviceDefinition('Error: "device" key is required: {}'.format(tag))

    # all keys should have values
    if '' in tag_dict.values():
        raise MissingValueInVolumeTagKey('Error: {}'.format(tag))

    # mountpoint value should be absolute path
    if 'mountpoint' in tag_dict:
        if not re.match('^\/[^\/]+.*', tag_dict['mountpoint']):
            raise InvalidMountPoint('Error: {}'.format(tag))

    return tag_dict


def ssm_online_waiter(instance_id):
    filters = [{'Key': 'InstanceIds', 'Values': [instance_id]}]
    status = None
    while status != 'Online':
        time.sleep(0.25)
        response = ssm_client.describe_instance_information(Filters=filters)
        if response['InstanceInformationList']:
            status = response['InstanceInformationList'][0].get('PingStatus')
    return True


def send_command(instance_id, device_info):
    """
    Send SSM command that will format and mount disk
    """

    parameters = {key: [value] for key, value in device_info.items()}
    options = {
        'InstanceIds': [instance_id],
        'DocumentName': SSM_DOCUMENT_NAME,
        'Parameters': parameters
    }

    logger.debug('Sending SSM command to {}: {}'.format(instance_id, options))
    response = ssm_client.send_command(**options)

    return response['Command']['CommandId']


def wait_for_command(instance_id, command_id):
    """
    Wait for SSM command invocation to finish
    Return True if success, else raise exception
    """

    result = {'Status': 'Pending'}

    while result['Status'] in ('Pending', 'InProgress', 'Delayed'):
        time.sleep(0.25)
        try:
            result = ssm_client.get_command_invocation(
                CommandId=command_id,
                InstanceId=instance_id,
            )
        except ClientError:
            pass

    if result['Status'] != 'Success':
        raise SsmCommandFailed('Error: {}'.format(result))

    return result


def attach_volumes(ebs_tag_keys, instance_id, az):
    """
    Attach EBS volumes and waits until they are attached
    """

    attachments = []

    volume_filters = [
        {
            'Name': 'tag-key',
            'Values': ebs_tag_keys,
        },
        {
            'Name': 'availability-zone',
            'Values': [az],
        }
    ]

    ebs_volumes = ec2_client.describe_volumes(Filters=volume_filters)
    check_status_code(ebs_volumes)
    if not ebs_volumes['Volumes']:
        raise NoMatchingVolumesFound('ERROR: {}'.format(ebs_volumes))

    # check if they are already attached
    volumes_to_attach = []
    for vol in ebs_volumes['Volumes']:
        if vol['Attachments']:
            attached_to = vol['Attachments'][0]['InstanceId']
            if attached_to == instance_id:
                # volume is already attached to the correct instance
                logger.info('Volume {} already attached to {}'.format(vol['VolumeId'], instance_id))
                continue
            else:
                # volume might be still detaching from previous instance
                # and we should include it in a list of volumes to attach
                logger.debug('Volume {} is attached to wrong instance {}'.format(vol['VolumeId'], attached_to))
                volumes_to_attach.append(vol)
        else:
            volumes_to_attach.append(vol)

    if not volumes_to_attach:
        logger.info('Nothing to do. All volumes already attached to {}'.format(instance_id))
        return []

    vol_ids = [v['VolumeId'] for v in volumes_to_attach]
    logger.debug('Volumes to attach: {}'.format(vol_ids))

    # we need instance in running state
    logger.debug('Waiting for instance to be in running state')
    instance_waiter = ec2_client.get_waiter('instance_running')
    instance_waiter.config.delay = 1
    instance_waiter.config.max_attempts = 300
    instance_waiter.wait(InstanceIds=[instance_id])
    logger.debug('Instance running, proceeding to volume attachement')

    # we need all volumes to be in an available state
    logger.debug('Waiting for all volumes to be available')
    volume_waiter = ec2_client.get_waiter('volume_available')
    volume_waiter.config.delay = 1
    volume_waiter.config.max_attempts = 300
    volume_waiter.wait(VolumeIds=vol_ids)
    logger.debug('All volumes are available. Attaching volumes.')

    disks_to_manage = []
    for ebs in volumes_to_attach:
        vol_id = ebs['VolumeId']
        vol_tag = [tag['Value'] for tag in ebs['Tags'] if tag['Key'] in ebs_tag_keys][0]
        logger.debug('Found volume tag: {}'.format(vol_tag))
        device_info = parse_validate_volume_tag(vol_tag)
        logger.debug('Parsed device information: {}'.format(device_info))
        if SSM_ENABLED:
            if 'label' in device_info or 'mountpoint' in device_info:
                disks_to_manage.append(device_info)

        response = ec2_client.attach_volume(
            Device=device_info['device'],
            InstanceId=instance_id,
            VolumeId=vol_id,
            DryRun=False
        )
        attachments.append(response)

    # wait until volumes are attached
    attached = ec2_client.get_waiter('volume_in_use')
    attached.config.delay = 1
    attached.config.max_attempts = 300
    attached.wait(
        VolumeIds=vol_ids,
        Filters=[
            {
                'Name': 'attachment.status',
                'Values': ['attached']
            }
        ]
    )

    logger.debug('disks_to_manage: {}'.format(disks_to_manage))

    if disks_to_manage:
        logger.debug('Waiting for instance to come online in SSM')
        ssm_online_waiter(instance_id)
        for disk in disks_to_manage:
            command_id = send_command(instance_id, disk)
            result = wait_for_command(instance_id, command_id)
            logger.info('Management of {} on {} completed successfully'.format(disk['device'], instance_id))
            logger.debug('SSM command output: {}'.format(result['StandardOutputContent']))

    return attachments


def lambda_handler(event, context):
    """
    Lambda handler function
    """

    logger.debug('Event: {}'.format(event))

    detail_types = ['EC2 Instance-launch Lifecycle Action', "Lambda EBS Attach Trigger"]
    if event['detail-type'] in detail_types:
        instance_id = event['detail']['EC2InstanceId']
        asg_name = event['detail']['AutoScalingGroupName']
        instance_data = ec2_client.describe_instances(InstanceIds=[instance_id])
        logger.debug('Instance Data: {}'.format(instance_data))

        ebs_tag_keys = parse_asg_tag(asg_name)
        logger.debug('EBS tag keys: {}'.format(ebs_tag_keys))

        az = instance_data['Reservations'][0]['Instances'][0]['Placement']['AvailabilityZone']
        attachments = attach_volumes(ebs_tag_keys, instance_id, az)
        for vol in attachments:
            logger.info('Attached {} as {} to {}'.format(vol['VolumeId'], vol['Device'], vol['InstanceId']))

        # Complete lifecycle hook
        # If no attachments then it means volumes were already attached
        # so there is not need to complete lifecycle action because the instance
        # is already in service.
        # If event was put by trigger then it won't have LifecycleActionToken
        if attachments and 'LifecycleActionToken' in event['detail']:
            asg_client.complete_lifecycle_action(
                LifecycleHookName=event['detail']['LifecycleHookName'],
                AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
                LifecycleActionToken=event['detail']['LifecycleActionToken'],
                LifecycleActionResult='CONTINUE'
            )
