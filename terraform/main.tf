# main.tf
# Main Terraform configuration file - wires together all modules

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get LabRole (for AWS Learner Lab)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Network Module - VPC, subnets, NAT gateway, security groups
module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  container_port       = var.container_port
}

# ECR Module - Container registry
module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repository_name
}

# Logging Module - CloudWatch log groups
module "logging" {
  source = "./modules/logging"

  project_name      = var.project_name
  retention_in_days = var.log_retention_days
}

# ALB Module - Application Load Balancer
module "alb" {
  source = "./modules/alb"

  project_name              = var.project_name
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  alb_security_group_id     = module.network.alb_security_group_id
  container_port            = var.container_port
  health_check_path         = var.health_check_path
  health_check_interval     = var.health_check_interval
  health_check_timeout      = var.health_check_timeout
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
}

# Messaging Module - SNS and SQS
module "messaging" {
  source = "./modules/messaging"

  sns_topic_name      = var.sns_topic_name
  sqs_queue_name      = var.sqs_queue_name
  visibility_timeout  = var.sqs_visibility_timeout
  message_retention   = var.sqs_message_retention
  receive_wait_time   = var.sqs_receive_wait_time
}

# ECS Module - ECS cluster and services
module "ecs" {
  source = "./modules/ecs"

  project_name                     = var.project_name
  aws_region                       = var.aws_region
  ecr_image_url                    = "${module.ecr.repository_url}:latest"
  container_port                   = var.container_port
  task_cpu                         = var.ecs_task_cpu
  task_memory                      = var.ecs_task_memory
  order_receiver_desired_count     = var.order_receiver_desired_count
  order_processor_desired_count    = var.order_processor_desired_count
  private_subnet_ids               = module.network.private_subnet_ids
  ecs_security_group_id            = module.network.ecs_security_group_id
  execution_role_arn               = data.aws_iam_role.lab_role.arn
  task_role_arn                    = data.aws_iam_role.lab_role.arn
  order_receiver_log_group         = module.logging.order_receiver_log_group_name
  order_processor_log_group        = module.logging.order_processor_log_group_name
  order_receiver_target_group_arn  = module.alb.order_receiver_target_group_arn
  order_processor_target_group_arn = ""  # Processor doesn't use ALB
  sns_topic_arn                    = module.messaging.sns_topic_arn
  sqs_queue_url                    = module.messaging.sqs_queue_url
  num_workers                      = var.num_workers

  # Ensure ALB listener rules are created before ECS services
  depends_on = [module.alb]
}

# Lambda Module - Order processing Lambda function (optional)
module "lambda" {
  count  = var.enable_lambda ? 1 : 0
  source = "./modules/lambda"

  function_name            = var.lambda_function_name
  runtime                  = "provided.al2"
  memory_size              = var.lambda_memory_size
  timeout                  = var.lambda_timeout
  deployment_package_path  = var.lambda_deployment_package
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  sns_topic_arn            = module.messaging.sns_topic_arn
  log_retention_days       = var.log_retention_days

  depends_on = [module.messaging]
}
