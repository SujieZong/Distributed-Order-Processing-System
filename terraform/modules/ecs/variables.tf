# modules/ecs/variables.tf

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_image_url" {
  description = "ECR image URL with tag"
  type        = string
}

variable "container_port" {
  description = "Port exposed by containers"
  type        = number
}

variable "task_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
}

variable "task_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
}

variable "order_receiver_desired_count" {
  description = "Desired number of order-receiver tasks"
  type        = number
}

variable "order_processor_desired_count" {
  description = "Desired number of order-processor tasks"
  type        = number
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS tasks"
  type        = string
}

variable "order_receiver_log_group" {
  description = "CloudWatch log group for order receiver"
  type        = string
}

variable "order_processor_log_group" {
  description = "CloudWatch log group for order processor"
  type        = string
}

variable "order_receiver_target_group_arn" {
  description = "Target group ARN for order receiver"
  type        = string
}

variable "order_processor_target_group_arn" {
  description = "Target group ARN for order processor"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue"
  type        = string
}

variable "num_workers" {
  description = "Number of worker goroutines for order processor"
  type        = number
  default     = 1
}
