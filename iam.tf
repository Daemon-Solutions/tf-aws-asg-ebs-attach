# Lambda policy for attaching EBS
data "aws_iam_policy_document" "ebs" {
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
    ]

    resources = [
      "*",
    ]
  }
}

# Lambda policy for running SSM command
data "aws_iam_policy_document" "ssm" {
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

data "aws_iam_policy_document" "lambda_policy" {
  source_json   = "${data.aws_iam_policy_document.ebs.json}"
  override_json = "${var.enable_ssm ? data.aws_iam_policy_document.ssm.json : ""}"
}
