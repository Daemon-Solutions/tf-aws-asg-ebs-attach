data "aws_availability_zones" "available" {}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

provider "aws" {
  region = "${var.aws_region}"
}
