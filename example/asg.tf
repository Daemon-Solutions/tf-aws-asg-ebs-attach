resource "aws_security_group" "ebs_attach" {
  name        = "ebs-attach"
  description = "ebs-attach"
  vpc_id      = "${module.ebs_attach_vpc.vpc_id}"

  tags = {
    Name = "ebs-attach"
  }
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ebs_attach.id}"
}

module "ebs_attach_asg" {
  source  = "git::ssh://git@gogs.bashton.net/Bashton-Terraform-Modules/tf-aws-asg.git"
  name    = "ebs-attach"
  envname = "ebs-attach"
  service = "ebs-attach"
  ami_id  = "ami-0bdb1d6c15a40392c"
  subnets = ["${element(module.ebs_attach_vpc.private_subnets, 0)}"]

  security_groups = [
    "${aws_security_group.ebs_attach.id}",
  ]

  iam_instance_profile = "${module.ebs_attach_iam.profile_id}"
  instance_type        = "t2.micro"
  user_data            = "#!/bin/bash\nyum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm\nsystemctl enable --now amazon-ssm-agent\n"
  min                  = "1"
  max                  = "1"

  extra_tags = [
    {
      key                 = "ebs_volumes"
      value               = "ebs_data_disk_0,ebs_data_disk_1"
      propagate_at_launch = false
    },
  ]
}

module "ebs_attach_iam" {
  source              = "git::ssh://git@gogs.bashton.net/Bashton-Terraform-Modules/tf-aws-iam-instance-profile.git"
  name                = "ebs-attach"
  ssm_session_manager = true
}
