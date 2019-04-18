module "ebs_attach" {
  source                 = "../"
  lambda_function_name   = "terraform-asg-ebs-attach-${random_string.random.result}"
  autoscaling_group_name = "${aws_autoscaling_group.asg.name}"
  asg_tag                = "ebs_volumes"
  lambda_log_level       = "DEBUG"
  enable_ssm             = true
}

resource "aws_ebs_volume" "ebs1" {
  availability_zone = "${element(data.aws_availability_zones.available.names, 0)}"
  size              = 1

  tags {
    ebs_data_disk_0 = "device=/dev/xvdf,mountpoint=/app/xvdf,label=XVDF"
  }
}

resource "aws_ebs_volume" "ebs2" {
  availability_zone = "${element(data.aws_availability_zones.available.names, 0)}"
  size              = 1

  tags {
    ebs_data_disk_1 = "device=xvdg,mountpoint=/app/xvdg"
  }
}

resource "aws_ebs_volume" "ebs3" {
  availability_zone = "${element(data.aws_availability_zones.available.names, 0)}"
  size              = 1

  tags {
    ebs_data_disk_0 = "device=xvdh"
  }
}
