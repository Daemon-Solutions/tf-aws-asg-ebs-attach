resource "aws_iam_instance_profile" "instance_profile" {
  name = "terraform-asg-ebs-attach-${random_string.random.result}"
  role = "${aws_iam_role.ebs_attach_role.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "ebs_attach_role" {
  name = "terraform-asg-ebs-attach-${random_string.random.result}-role"

  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "ssm_session_manager" {
  statement {
    sid    = "ForSSMmanaged"
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "ForSessionManager"
    effect = "Allow"

    actions = [
      "s3:GetEncryptionConfiguration",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "ssm_session_manager" {
  name   = "terraform-asg-ebs-attach-${random_string.random.result}"
  role   = "${aws_iam_role.ebs_attach_role.id}"
  policy = "${data.aws_iam_policy_document.ssm_session_manager.json}"

  lifecycle {
    create_before_destroy = true
  }
}
