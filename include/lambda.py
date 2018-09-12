#!/usr/bin/python3

import boto3
import botocore
import os
import logging
import sys

# get logger
logger = logging.getLogger()
logger.setLevel(os.environ['LOG_LEVEL'].upper())

# tag key identifying volumes we should look for
ASG_TAG = os.environ['ASG_TAG']

# the name of the lifecycle hook this function should process
LIFECYCLE_HOOK_NAME = os.environ['LIFECYCLE_HOOK_NAME']

# get current region, it is in ENV by default
AWS_REGION = os.environ['AWS_DEFAULT_REGION']

# clients
ec2_client = boto3.client('ec2', region_name=AWS_REGION)
asg_client = boto3.client('autoscaling', region_name=AWS_REGION)


class BadHTTPStatusCode(Exception):
    pass


class NoMatchingVolumesFound(Exception):
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


def attach_volumes(ebs_tag_keys, instance_id, az):
    """
    Attach EBS volumes and waits until they are attached
    """

    attachements = []

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
                logger.info('Volume {} already attached to {}'.format(vol['VolumeId'], instance_id))
            else:
                logger.info('Volume {} is attached to wrong instance {}'.format(vol['VolumeId'], attached_to))
        else:
            volumes_to_attach.append(vol)

    if not volumes_to_attach:
        logger.info('Nothing to do. All volumes already attached to {}'.format(instance_id))
        return []

    vol_ids = [v['VolumeId'] for v in volumes_to_attach]
    logger.info('Volumes to attach: {}'.format(vol_ids))

    # we need instance in running state
    logger.info('Waiting for instance to be in running state')
    waiter = ec2_client.get_waiter('instance_running')
    waiter.config.delay = 1
    waiter.config.max_attempts = 300
    waiter.wait(InstanceIds=[instance_id])
    logger.info('Instance running, proceeding to volume attachement')

    # we need all volumes to be in an available state
    logger.info('Waiting for all volumes to be available')
    waiter = ec2_client.get_waiter('volume_available')
    waiter.config.delay = 1
    waiter.config.max_attempts = 300
    waiter.wait(VolumeIds=vol_ids)
    logger.info('All volumes are available. Attaching volumes.')

    for ebs in volumes_to_attach:
        vol_id = ebs['VolumeId']
        device = [tag['Value'] for tag in ebs['Tags'] if tag['Key'] in ebs_tag_keys][0]

        response = ec2_client.attach_volume(
            Device=device,
            InstanceId=instance_id,
            VolumeId=vol_id,
            DryRun=False
        )
        attachements.append(response)

    # wait until volumes are attached
    attached = ec2_client.get_waiter('volume_in_use')
    waiter.config.delay = 1
    waiter.config.max_attempts = 300
    waiter.wait(
        VolumeIds=vol_ids,
        Filters=[
            {
                'Name': 'attachment.status',
                'Values': ['attached']
            }
        ]
    )

    logger.info('Volumes {} attached to {}'.format(vol_ids, instance_id))

    return attachements


def lambda_handler(event, context):
    """
    Lambda handler function
    """

    logger.info('Event: {}'.format(event))

    detail_types = ['EC2 Instance-launch Lifecycle Action', "Lambda EBS Attach Trigger"]
    if event['detail-type'] in detail_types:
        if event['detail']['LifecycleHookName'] != LIFECYCLE_HOOK_NAME:
            logger.info('Not my concern, exiting.')
            sys.exit(0)
        instance_id = event['detail']['EC2InstanceId']
        asg_name = event['detail']['AutoScalingGroupName']
        instance_data = ec2_client.describe_instances(InstanceIds=[instance_id])
        logger.info('Instance Data: {}'.format(instance_data))

        ebs_tag_keys = parse_asg_tag(asg_name)
        logger.info('EBS tag keys: {}'.format(ebs_tag_keys))

        az = instance_data['Reservations'][0]['Instances'][0]['Placement']['AvailabilityZone']
        attachments = attach_volumes(ebs_tag_keys, instance_id, az)
        for vol in attachments:
            logger.info('Attached {} as {} to {}'.format(vol['VolumeId'], vol['Device'], vol['InstanceId']))

        # Complete lifecycle hook
        # If no attachments then it means volumes were already attached
        # so there is not need to complete lifecycle action because the instance
        # is already in service.
        if attachments:
            asg_client.complete_lifecycle_action(
                LifecycleHookName=event['detail']['LifecycleHookName'],
                AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
                LifecycleActionToken=event['detail']['LifecycleActionToken'],
                LifecycleActionResult='CONTINUE'
            )
