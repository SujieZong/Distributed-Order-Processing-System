# terraform.tfvars
# Customize these values for your deployment

# AWS Configuration
aws_region = "us-west-2"

# Project Configuration
project_name = "order-processing"
environment  = "dev"

# VPC Configuration (using specified CIDRs)
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["us-west-2a", "us-west-2b"]

# ECS Configuration
ecs_task_cpu    = 256  # 0.25 vCPU
ecs_task_memory = 512  # 512 MB

order_receiver_desired_count  = 2
order_processor_desired_count = 0

container_port = 8080

# ECR Configuration
ecr_repository_name = "order-processing-service"

# SQS Configuration (as specified)
sqs_visibility_timeout = 30      # 30 seconds
sqs_message_retention  = 345600  # 4 days in seconds
sqs_receive_wait_time  = 20      # 20 seconds for long polling

# SNS Configuration
sns_topic_name = "order-processing-events"
sqs_queue_name = "order-processing-queue"

# ALB Health Check Configuration
health_check_path                = "/health"
health_check_interval            = 30
health_check_timeout             = 5
health_check_healthy_threshold   = 2
health_check_unhealthy_threshold = 3

# Logging Configuration
log_retention_days = 7

# IAM Configuration (leave empty to auto-detect LabRole)
# If you need to specify a different role, uncomment and set the ARN:
# lab_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/LabRole"
enable_lambda = true
