# variables.tf
# Core infrastructure configuration variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "order-processing"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
  default     = 512
}

variable "order_receiver_desired_count" {
  description = "Desired number of order-receiver tasks"
  type        = number
  default     = 1
}

variable "order_processor_desired_count" {
  description = "Desired number of order-processor tasks"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

# ECR Configuration
variable "ecr_repository_name" {
  description = "ECR repository name for container images"
  type        = string
  default     = "order-processing-service"
}

# SQS Configuration
variable "sqs_visibility_timeout" {
  description = "SQS visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "sqs_message_retention" {
  description = "SQS message retention in seconds (4 days)"
  type        = number
  default     = 345600
}

variable "sqs_receive_wait_time" {
  description = "SQS receive wait time for long polling in seconds"
  type        = number
  default     = 20
}

# SNS Configuration
variable "sns_topic_name" {
  description = "SNS topic name for order processing events"
  type        = string
  default     = "order-processing-events"
}

variable "sqs_queue_name" {
  description = "SQS queue name for order processing"
  type        = string
  default     = "order-processing-queue"
}

# ALB Configuration
variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# IAM Configuration
variable "lab_role_arn" {
  description = "ARN of the LabRole for AWS Learner Lab (will be constructed)"
  type        = string
  default     = ""
}

# Worker Configuration
variable "num_workers" {
  description = "Number of worker goroutines for order processor (1, 5, 20, or 100 for scaling experiments)"
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 5, 20, 100], var.num_workers)
    error_message = "num_workers must be 1, 5, 20, or 100 for Phase 5 experiments"
  }
}

# Lambda Configuration
variable "enable_lambda" {
  description = "Enable Lambda function for order processing"
  type        = bool
  default     = false
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "order-processor-lambda"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "lambda_deployment_package" {
  description = "Path to Lambda deployment package (relative to terraform directory)"
  type        = string
  default     = "../lambda/function.zip"
}
