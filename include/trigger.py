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

# autoscaling groups (coma delimited)
asgs = sys.argv[1].split(',')
# asg lifecycle hook name
lifecycle_hook_name = sys.argv[2]

# client
cloudwatch_events = boto3.client('events')
asg_client = boto3.client('autoscaling')

asgs = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=asgs)
logger.debug('Auto Scaling Groups: {}'.format(asgs))
entries = []

for asg in asgs['AutoScalingGroups']:
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
logger.info('Sending event to cloudwatch for {}'.format(instance))
response = cloudwatch_events.put_events(Entries=entries)
logger.info('API response: {}'.format(json.dumps(response, indent=2)))
