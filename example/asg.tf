resource "random_string" "random" {
  length  = 8
  special = false
  number  = false
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = "terraform-asg-ebs-attach-${random_string.random.result}"
  cidr               = "10.0.0.0/24"
  azs                = ["${element(data.aws_availability_zones.available.names, 0)}"]
  public_subnets     = ["10.0.0.128/25"]
  enable_nat_gateway = false
}

resource "aws_security_group" "ebs_attach" {
  name   = "terraform-asg-ebs-attach-${random_string.random.result}"
  vpc_id = "${module.vpc.vpc_id}"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ebs_attach.id}"
}

resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ebs_attach.id}"
}

resource "aws_launch_configuration" "lc" {
  name                        = "terraform-aws-asg-ebs-attach-${random_string.random.result}"
  image_id                    = "${data.aws_ami.ami.image_id}"
  instance_type               = "t2.micro"
  user_data                   = "#!/bin/bash\nyum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm\nsystemctl enable --now amazon-ssm-agent\n"
  iam_instance_profile        = "${aws_iam_instance_profile.instance_profile.id}"
  associate_public_ip_address = true
  key_name                    = "${var.key_name}"

  security_groups = [
    "${aws_security_group.ebs_attach.id}",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier       = ["${module.vpc.public_subnets}"]
  name                      = "terraform-aws-asg-ebs-attach-${random_string.random.result}"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  launch_configuration      = "${aws_launch_configuration.lc.name}"

  tag {
    key                 = "ebs_volumes"
    value               = "ebs_data_disk_0,ebs_data_disk_1"
    propagate_at_launch = false
  }
}
