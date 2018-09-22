resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = "${var.lambda_logs_retention_in_days}"
}

## create lambda package
data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/include/lambda.py"
  output_path = "${path.cwd}/.terraform/tf-aws-asg-ebs-attach-${md5(file("${path.module}/include/lambda.py"))}.zip"
}

## create lambda function
resource "aws_lambda_function" "ebs_attach" {
  depends_on = [
    "aws_cloudwatch_log_group.lambda_log_group",
    "data.archive_file.lambda_package",
  ]

  filename         = ".terraform/tf-aws-asg-ebs-attach-${md5(file("${path.module}/include/lambda.py"))}.zip"
  source_code_hash = "${data.archive_file.lambda_package.output_base64sha256}"
  function_name    = "${var.lambda_function_name}"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "lambda.lambda_handler"
  runtime          = "python3.6"
  timeout          = "300"
  publish          = true

  environment = {
    variables = {
      LOG_LEVEL           = "${var.lambda_log_level}"
      ASG_TAG             = "${var.asg_tag}"
      LIFECYCLE_HOOK_NAME = "${var.lifecycle_hook_name}"
    }
  }
}

resource "null_resource" "put_cloudwatch_event" {
  triggers {
    source_code_hash = "${data.archive_file.lambda_package.output_base64sha256}"
    asg_list         = "${md5(join(",", sort(var.autoscaling_group_names)))}"
  }

  depends_on = [
    "aws_cloudwatch_event_rule.ebs_attach_rule",
    "aws_cloudwatch_event_target.ebs_attach",
    "aws_autoscaling_lifecycle_hook.aws_autoscaling_lifecycle_hook",
    "aws_lambda_function.ebs_attach",
  ]

  provisioner "local-exec" {
    command = "${path.module}/include/trigger.py ${join(",", var.autoscaling_group_names)} ${var.lifecycle_hook_name} ${data.aws_region.current.name}"
  }
}
