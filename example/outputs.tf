output "asg_name" {
  value = aws_autoscaling_group.asg.name
}

output "aws_region" {
  value = var.aws_region
}
