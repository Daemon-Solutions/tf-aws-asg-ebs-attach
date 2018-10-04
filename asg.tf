# ASG lifecycle hook
resource "aws_autoscaling_lifecycle_hook" "aws_autoscaling_lifecycle_hook" {
  name                   = "${var.lifecycle_hook_name}"
  autoscaling_group_name = "${var.autoscaling_group_name}"
  default_result         = "ABANDON"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
}
