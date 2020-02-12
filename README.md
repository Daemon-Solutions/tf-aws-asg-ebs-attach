# tf-aws-asg-ebs-attach


This module attaches ebs volume to instances in ASG upon instance launch.
Instance is placed in `pending:wait` state until volume(s) are attached, failure to attach volume results in instance being terminated. ASG will then spin a new one and the process repeats. It is left for a user to monitor such failures.

This module does not manage EBS volumes and they need to be created by other means.

ASG defined in `autoscaling_group_name` variable has to be tagged with a tag defined in `asg_tag` variable. The value of this tag should be a coma-delimited string containing tag keys on EBS volumes for this autoscaling group.

Value of a tag on an EBS volume must contain a coma-delimited values:
- `device=xvdf` - required
- `mountpoint=/an/absolute/path` - optional
- `label=partitionLabel` - optional

See example below or example folder.

```hcl

# module itself
module "ebs_attach" {
  source                 = "/home/tf/tf-aws-asg-ebs-attach"
  lambda_function_name   = "lambda-ebs-attach"
  autoscaling_group_name = module.myapp.asg_name
  asg_tag                = "ebs_volumes"
  enable_ssm             = true
}

# my_app
module "myapp" {
  source  = "git::ssh://git@gogs.bashton.net/Bashton-Terraform-Modules/tf-aws-asg.git"
  name    = "my_app"
  subnets = [element(module.vpc.private_subnets, 0)]
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

## this volume will be partitioned, partition will be labeled as MYAPP and mounted on /data/myapp
resource "aws_ebs_volume" "asg_0_1" {
  availability_zone = "eu-west-1a"
  size              = 100

  # value must be the device name (for example, /dev/sdh or xvdf)
  tags {
    myapp_data = "device=xvdf,label=MYAPP,mountpoint=/data/myapp"
  }
}

## this volume will be partitioned and labeled only
resource "aws_ebs_volume" "asg_0_2" {
  availability_zone = "eu-west-1a"
  size              = 1000

  tags {
    myapp_logs = "device=/dev/xvdg,label=LOGS"
  }
}
```

# Terraform version compatibility

| Module version | Terraform version |
|----------------|-------------------|
| 1.x.x          | 0.12.x            |
| 0.x.x          | 0.11.x            |
