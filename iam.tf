# Lambda policy for attaching EBS
data "aws_iam_policy_document" "ebs_lambda" {
  statement {
    actions = [
      "ec2:AttachVolume",
      "ec2:DescribeVolumeAttribute",
      "ec2:DescribeVolumeStatus",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeInstances",
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:Describe*",
      "kms:CreateGrant",
    ]

    resources = [
      "*",
    ]
  }
}

# Lambda policy for running SSM command
data "aws_iam_policy_document" "ssm_lambda" {
  count = "${var.enable_ssm}"

  statement {
    actions = [
      "ssm:SendCommand",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:document/${aws_ssm_document.ssm.name}",
    ]
  }

  statement {
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation",
    ]

    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*",
    ]
  }
}

# Attach ssm policy to lambda role
resource "aws_iam_policy" "ssm_lambda" {
  count  = "${var.enable_ssm}"
  name   = "${module.lambda.function_name}-ssm"
  policy = "${data.aws_iam_policy_document.ssm_lambda.json}"
}

resource "aws_iam_policy_attachment" "ssm_lambda" {
  count      = "${var.enable_ssm}"
  name       = "${module.lambda.function_name}"
  roles      = ["${module.lambda.role_name}"]
  policy_arn = "${aws_iam_policy.ssm_lambda.arn}"
}
