# Lambda function
module "lambda" {
  source        = "github.com/claranet/terraform-aws-lambda?ref=v0.11.3"
  function_name = "${var.lambda_function_name}"
  description   = "Attaches EBS volumes for instances in ${var.autoscaling_group_name} AutoScaling Group"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.6"
  timeout       = 300
  source_path   = "${path.module}/include/lambda.py"
  attach_policy = true
  policy        = "${data.aws_iam_policy_document.lambda_policy.json}"

  environment {
    variables {
      LOG_LEVEL         = "${var.lambda_log_level}"
      ASG_TAG           = "${var.asg_tag}"
      SSM_DOCUMENT_NAME = "${var.ssm_document_name}"
      SSM_ENABLED       = "${var.enable_ssm ? "true" : "false"}"
    }
  }
}

resource "null_resource" "put_cloudwatch_event" {
  depends_on = [
    "aws_cloudwatch_event_rule.ebs_attach_rule",
    "aws_cloudwatch_event_target.ebs_attach",
    "aws_autoscaling_lifecycle_hook.aws_autoscaling_lifecycle_hook",
  ]

  triggers {
    lambda_arn = "${module.lambda.function_arn}"
    asg        = "${var.autoscaling_group_name}"
  }

  provisioner "local-exec" {
    command = "${path.module}/include/trigger.py ${var.autoscaling_group_name} ${var.lifecycle_hook_name} ${data.aws_region.current.name}"
  }
}
