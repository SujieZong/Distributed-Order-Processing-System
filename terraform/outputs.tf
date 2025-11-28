# outputs.tf
# Terraform outputs for easy access to important values

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway"
  value       = module.network.nat_gateway_ip
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "order_receiver_service_name" {
  description = "Name of the order receiver ECS service"
  value       = module.ecs.order_receiver_service_name
}

output "order_processor_service_name" {
  description = "Name of the order processor ECS service"
  value       = module.ecs.order_processor_service_name
}

# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# SNS/SQS Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = module.messaging.sns_topic_arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = module.messaging.sns_topic_name
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.messaging.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = module.messaging.sqs_queue_arn
}

output "sqs_queue_name" {
  description = "Name of the SQS queue"
  value       = module.messaging.sqs_queue_name
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = module.messaging.sqs_dlq_url
}

# CloudWatch Logs Outputs
output "order_receiver_log_group" {
  description = "CloudWatch log group for order receiver"
  value       = module.logging.order_receiver_log_group_name
}

output "order_processor_log_group" {
  description = "CloudWatch log group for order processor"
  value       = module.logging.order_processor_log_group_name
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.network.alb_security_group_id
}

output "ecs_tasks_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = module.network.ecs_security_group_id
}

# Helpful Commands
output "useful_commands" {
  description = "Useful commands for deployment and testing"
  value = {
    # ECR Login
    ecr_login = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}"
    
    # Docker Build and Push
    docker_build = "docker build --platform linux/amd64 -t ${module.ecr.repository_url}:latest ../src"
    docker_push  = "docker push ${module.ecr.repository_url}:latest"
    
    # Test Health Check
    test_health = "curl http://${module.alb.alb_dns_name}/health"
    
    # Test Order Receiver (sync)
    test_sync = "curl -X POST http://${module.alb.alb_dns_name}/orders/sync -H 'Content-Type: application/json' -d @../src/sample_order.json"
    
    # Test Order Processor (async)
    test_async = "curl -X POST http://${module.alb.alb_dns_name}/orders/async -H 'Content-Type: application/json' -d @../src/sample_order.json"
    
    # View ECS Logs (order-receiver)
    view_receiver_logs = "aws logs tail ${module.logging.order_receiver_log_group_name} --follow --region ${var.aws_region}"
    
    # View ECS Logs (order-processor)
    view_processor_logs = "aws logs tail ${module.logging.order_processor_log_group_name} --follow --region ${var.aws_region}"
    
    # Force new deployment
    update_receiver  = "aws ecs update-service --cluster ${module.ecs.cluster_name} --service ${module.ecs.order_receiver_service_name} --force-new-deployment --region ${var.aws_region}"
    update_processor = "aws ecs update-service --cluster ${module.ecs.cluster_name} --service ${module.ecs.order_processor_service_name} --force-new-deployment --region ${var.aws_region}"
  }
}

# Summary
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    alb_url              = "http://${module.alb.alb_dns_name}"
    ecr_repository       = module.ecr.repository_url
    ecs_cluster          = module.ecs.cluster_name
    order_receiver       = module.ecs.order_receiver_service_name
    order_processor      = module.ecs.order_processor_service_name
    sns_topic            = module.messaging.sns_topic_name
    sqs_queue            = module.messaging.sqs_queue_name
    vpc_id               = module.network.vpc_id
    region               = var.aws_region
  }
}

# AWS Region Output
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

# Lambda Outputs (conditional)
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = var.enable_lambda ? module.lambda[0].function_name : "Not deployed"
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = var.enable_lambda ? module.lambda[0].function_arn : "Not deployed"
}

output "lambda_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = var.enable_lambda ? module.lambda[0].log_group_name : "Not deployed"
}
