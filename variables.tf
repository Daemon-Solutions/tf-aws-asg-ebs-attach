variable "lambda_function_name" {}

variable "autoscaling_group_names" {
  type        = "list"
  description = "Name of the AutoscalingGroup to attach this Lambda function to"
}

# variable "autoscaling_group_arns" {
#   type        = "list"
#   description = "ARNs of the AutoscalingGroup to attach this Lambda function to"
# }

variable "asg_tag" {
  description = "ASG tag key to read values from"
}

variable "lambda_logs_retention_in_days" {
  default = "30"
}

variable "lambda_log_level" {
  description = "Log level for lambda function. Valid options are those of python logging module: CRITICAL, ERROR, WARNING, INFO, DEBUG"
  default     = "INFO"
}

variable "lifecycle_hook_name" {
  default = "lambda-ebs-attach"
}

variable "enable_ssm" {
  description = "Whether to enable creation of ssm document"
  default     = false
}

variable "ssm_document_name" {
  default = "tf-aws-asg-attach-mangage-disk"
}

variable "ssm_document_format" {
  description = "SSM document format. Possible values are YAML and JSON"
  type        = "string"
  default     = "YAML"
}

variable "ssm_document_path" {
  description = "Path to the SSM document"
  type        = "string"
  default     = ""
}
