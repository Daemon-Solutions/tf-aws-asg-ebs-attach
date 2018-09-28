module "ebs_attach_vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "ebs-attach"
  cidr            = "10.0.0.0/24"
  azs             = ["eu-west-1a"]
  private_subnets = ["10.0.0.0/25"]
  public_subnets  = ["10.0.0.128/25"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_s3_endpoint = true

  tags = {
    Environment = "ebs-attach"
  }
}
