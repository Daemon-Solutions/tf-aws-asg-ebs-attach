variable "lambda_function_name" {
  description = "Name for the lambda function"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the AutoscalingGroup to attach this Lambda function to"
  type        = string
}

variable "asg_tag" {
  description = "ASG tag key containing name of the tag key on EBS volumes"
  type        = string
}

variable "lambda_log_level" {
  description = "Log level for lambda function. Valid options are those of python logging module: CRITICAL, ERROR, WARNING, INFO, DEBUG"
  default     = "INFO"
}

variable "lifecycle_hook_name" {
  description = "Name for the ASG LifecycleHook"
  type        = string
  default     = "lambda-ebs-attach"
}

variable "enable_ssm" {
  description = "Whether to enable creation of ssm document"
  default     = false
}

variable "ssm_document_name" {
  description = "Name for the SSM document"
  type        = string
  default     = "tf-aws-asg-ebs-attach-manage-disk"
}

variable "ssm_document_format" {
  description = "SSM document format. Possible values are YAML and JSON"
  type        = string
  default     = "YAML"
}

variable "ssm_document_path" {
  description = "Path to the SSM document"
  type        = string
  default     = ""
}
