# tf-aws-asg-ebs-attach


This module attaches ebs volume to instances in ASG upon instance launch.
Instance is placed in `pending:wait` state until volume(s) are attached, failure to attach volume results in instance being terminated. ASG will then spin a new one and the process repeats. It is left for a user to monitor such failures.

Module should be deployed once per account.
This module does not manage EBS volumes and they need to be created by other means.

Each ASG defined in `autoscaling_group_names` variable has to be tagged with a tag defined in `asg_tag` variable. The value of this tag should be a coma-delimited string containing tag keys on EBS volumes for this autoscaling group.

Value of tags on EBS volume must contain a device name EBS should be attached as. Please see example below.

```hcl

# module itself
module "ebs_attach" {
  source               = "/home/tf/tf-aws-asg-ebs-attach"
  lambda_function_name = "lambda-ebs-attach"

  autoscaling_group_names = [
    "${module.myapp.asg_name}",
    "${module.jenkins.asg_name}",
  ]

  asg_tag = "ebs_volumes"
}

# my_app
module "myapp" {
  source  = "git::ssh://git@gogs.bashton.net/Bashton-Terraform-Modules/tf-aws-asg.git"
  name    = "my_app"
  subnets = ["${element(module.vpc.private_subnets, 0)}"]
  [...]

  extra_tags = [
    {
      key                 = "ebs_volumes"
      value               = "myapp_data,myapp_logs"
      # instances don't need this tag
      propagate_at_launch = false
    },
  ]
}

# EBS volumes
resource "aws_ebs_volume" "asg_0_1" {
  availability_zone = "eu-west-1a"
  size              = 100

  # value must be the device name (for example, /dev/sdh or xvdf)
  tags {
    myapp_data = "xvdf"
  }
}

resource "aws_ebs_volume" "asg_0_2" {
  availability_zone = "eu-west-1a"
  size              = 1000

  tags {
    myapp_logs = "/dev/xvdg"
  }
}


# asg_1
module "jenkins" {
  source  = "git::ssh://git@gogs.bashton.net/Bashton-Terraform-Modules/tf-aws-asg.git"
  name    = "jenkins"
  subnets = ["${element(module.vpc.private_subnets, 0)}"]
  [...]

  extra_tags = [
    {
      key                 = "ebs_volumes"
      value               = "jenkins_docker_disk,jenkins_jenkins_disk"
      # instances don't need this tag
      propagate_at_launch = false
    },
  ]
}

# EBS volumes
resource "aws_ebs_volume" "jenkins_1" {
  availability_zone = "eu-west-1a"
  size              = 100

  tags {
    jenkins_docker_disk = "xvdf"
  }
}

resource "aws_ebs_volume" "jenkins_2" {
  availability_zone = "eu-west-1a"
  size              = 100

  tags {
    jenkins_jenkins_disk = "xvdf"
  }
}

```
