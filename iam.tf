# Lambda role
resource "aws_iam_role" "lambda_role" {
  name_prefix = "lambda-ebs-attach"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Lambda policy for managing logs
resource "aws_iam_role_policy" "lambda_logging_policy" {
  name_prefix = "lambda-ebs-attach"
  role        = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

# Lambda policy for attaching EBS
resource "aws_iam_role_policy" "lambda_ebs_attach_policy" {
  name_prefix = "lambda-ebs-attach"
  role        = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:DescribeVolumeAttribute",
        "ec2:DescribeVolumeStatus",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications",
        "ec2:DescribeInstances",
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
