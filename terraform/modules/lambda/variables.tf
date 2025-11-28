# modules/lambda/variables.tf
# Input variables for Lambda module

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "order-processor-lambda"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "provided.al2"  # For Go custom runtime
}

variable "memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "deployment_package_path" {
  description = "Path to the Lambda deployment package (zip file)"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the IAM role for Lambda execution (LabRole)"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to subscribe to"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "log_level" {
  description = "Log level for the Lambda function"
  type        = string
  default     = "INFO"
}
