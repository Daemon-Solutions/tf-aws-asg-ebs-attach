#!/usr/bin/env python3

import boto3
import json
import sys
from datetime import datetime
import logging

LOG_LEVEL = 'DEBUG'
logger = logging.getLogger('tf-aws-asg-ebs-attach')
level = logging.getLevelName(LOG_LEVEL)
logger.setLevel(level)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(level)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

# autoscaling group name
asg_name = sys.argv[1]
# asg lifecycle hook name
lifecycle_hook_name = sys.argv[2]
region_name = sys.argv[3]

# client
cloudwatch_events = boto3.client('events', region_name=region_name)
asg_client = boto3.client('autoscaling', region_name=region_name)

asg_result = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
logger.debug('Auto Scaling Group data: {}'.format(asg_result))

# check if there is an ASG at all and if it has any instances
if asg_result['AutoScalingGroups']:
    asg = asg_result['AutoScalingGroups'][0]
    if not asg['Instances']:
        logger.info('No instances found in {}'.format(asg_name))
        sys.exit()
else:
    logger.info('Autoscaling Group not found')
    sys.exit()

entries = []
asg_arn = asg['AutoScalingGroupARN']
asg_name = asg['AutoScalingGroupName']
instances = [i['InstanceId'] for i in asg['Instances']]

for instance in instances:
    entries.append(
        {
            'Time': datetime.now(),
            'Detail': json.dumps(
                {
                    'AutoScalingGroupName': asg_name,
                    'LifecycleHookName': 'lambda-ebs-attach',
                    'EC2InstanceId': instance,
                    'LifecycleTransition': 'autoscaling:EC2_INSTANCE_LAUNCHING'
                }
            ),
            'DetailType': 'Lambda EBS Attach Trigger',
            'Resources': [asg_arn],
            'Source': 'lambda_ebs.trigger'
        }
    )

# put events
logger.debug('Event entries: {}'.format(entries))
logger.info('Sending event to cloudwatch for {}'.format(", ".join(instances)))
response = cloudwatch_events.put_events(Entries=entries)
logger.info('API response: {}'.format(json.dumps(response, indent=2)))
