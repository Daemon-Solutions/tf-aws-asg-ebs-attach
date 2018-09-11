module "ebs_attach" {
  source               = "git::ssh://git@gogs.bashton.net/Bashton-Terraform-Modules/tf-aws-asg-ebs-attach.git"
  lambda_function_name = "lambda-ebs-attach"

  autoscaling_group_names = [
    "${module.ebs_attach_asg.asg_name}",
  ]

  asg_tag = "ebs_volumes"
}

resource "aws_ebs_volume" "ebs1" {
  availability_zone = "eu-west-1a"
  size              = 1

  tags {
    ebs_data_disk_0 = "xvdf"
  }
}

resource "aws_ebs_volume" "ebs2" {
  availability_zone = "eu-west-1a"
  size              = 1

  tags {
    ebs_data_disk_1 = "xvdg"
  }
}

resource "aws_ebs_volume" "ebs3" {
  availability_zone = "eu-west-1a"
  size              = 1

  tags {
    ebs_logs_disk_0 = "xvdh"
  }
}
