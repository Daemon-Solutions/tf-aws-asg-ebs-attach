resource "aws_cloudwatch_event_rule" "ebs_attach_rule" {
  description = "Trigger for lambda ebs attach"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling",
    "lambda_ebs.trigger"
  ],
  "detail-type": [
    "EC2 Instance-launch Lifecycle Action",
    "Lambda EBS Attach Trigger"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${var.autoscaling_group_name}"
    ],
    "LifecycleHookName": [
      "${var.lifecycle_hook_name}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "ebs_attach" {
  rule = "${aws_cloudwatch_event_rule.ebs_attach_rule.name}"
  arn  = "${module.lambda.function_arn}"
}

resource "aws_lambda_permission" "aws_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${module.lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ebs_attach_rule.arn}"
}
