data "aws_availability_zones" "available" {}

provider "aws" {
  region = "eu-west-1"
}
