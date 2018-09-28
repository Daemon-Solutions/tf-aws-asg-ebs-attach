module "ebs_attach" {
  source               = "../"
  lambda_function_name = "lambda-ebs-attach"

  autoscaling_group_names = [
    "${module.ebs_attach_asg.asg_name}",
  ]

  asg_tag          = "ebs_volumes"
  lambda_log_level = "DEBUG"
  enable_ssm       = true
}

resource "aws_ebs_volume" "ebs1" {
  availability_zone = "eu-west-1a"
  size              = 1

  tags {
    ebs_data_disk_0 = "device=/dev/xvdf,mountpoint=/app/xvdf,label=XVDF"
  }
}

resource "aws_ebs_volume" "ebs2" {
  availability_zone = "eu-west-1a"
  size              = 1

  tags {
    ebs_data_disk_1 = "device=xvdg,mountpoint=/app/xvdg"
  }
}

resource "aws_ebs_volume" "ebs3" {
  availability_zone = "eu-west-1a"
  size              = 1

  tags {
    ebs_data_disk_0 = "device=xvdh"
  }
}
