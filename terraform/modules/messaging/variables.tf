# modules/messaging/variables.tf

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "visibility_timeout" {
  description = "SQS visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "message_retention" {
  description = "SQS message retention in seconds"
  type        = number
  default     = 345600  # 4 days
}

variable "receive_wait_time" {
  description = "SQS receive wait time for long polling in seconds"
  type        = number
  default     = 20
}
