#!/bin/bash
# validate_terraform.sh
# Script to validate Terraform configuration

set -e

echo "========================================="
echo "Terraform Configuration Validation"
echo "========================================="

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    echo "   Install from: https://www.terraform.io/downloads"
    exit 1
fi

echo "✅ Terraform is installed: $(terraform version | head -n1)"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    echo "   Install from: https://aws.amazon.com/cli/"
    exit 1
fi

echo "✅ AWS CLI is installed: $(aws --version)"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials are not configured"
    echo "   Run: aws configure"
    exit 1
fi

echo "✅ AWS credentials are configured"
echo "   Account: $(aws sts get-caller-identity --query Account --output text)"
echo "   User: $(aws sts get-caller-identity --query Arn --output text)"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker is not installed (required for building images)"
    echo "   Install from: https://www.docker.com/get-started"
else
    echo "✅ Docker is installed: $(docker --version)"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "⚠️  Docker daemon is not running"
    else
        echo "✅ Docker daemon is running"
    fi
fi

echo ""
echo "========================================="
echo "Validating Terraform Configuration"
echo "========================================="

# Initialize Terraform (in temp directory to avoid state issues)
echo "Initializing Terraform..."
terraform init -backend=false > /dev/null 2>&1

# Format check
echo "Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    echo "✅ Terraform files are properly formatted"
else
    echo "⚠️  Terraform files need formatting"
    echo "   Run: terraform fmt -recursive"
fi

# Validate configuration
echo "Validating Terraform configuration..."
if terraform validate; then
    echo "✅ Terraform configuration is valid"
else
    echo "❌ Terraform configuration has errors"
    exit 1
fi

echo ""
echo "========================================="
echo "Configuration Summary"
echo "========================================="

# Parse terraform.tfvars to show key settings
if [ -f "terraform.tfvars" ]; then
    echo "Project Settings:"
    echo "  Region: $(grep 'aws_region' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')"
    echo "  Project: $(grep 'project_name' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')"
    echo "  Environment: $(grep 'environment' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')"
    echo ""
    echo "Network Configuration:"
    echo "  VPC CIDR: $(grep 'vpc_cidr' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')"
    echo "  Public Subnets: $(grep 'public_subnet_cidrs' terraform.tfvars | cut -d'=' -f2)"
    echo "  Private Subnets: $(grep 'private_subnet_cidrs' terraform.tfvars | cut -d'=' -f2)"
    echo ""
    echo "ECS Configuration:"
    echo "  CPU: $(grep 'ecs_task_cpu' terraform.tfvars | cut -d'=' -f2 | tr -d ' ') units"
    echo "  Memory: $(grep 'ecs_task_memory' terraform.tfvars | cut -d'=' -f2 | tr -d ' ') MB"
    echo "  Order Receiver Tasks: $(grep 'order_receiver_desired_count' terraform.tfvars | cut -d'=' -f2 | tr -d ' ')"
    echo "  Order Processor Tasks: $(grep 'order_processor_desired_count' terraform.tfvars | cut -d'=' -f2 | tr -d ' ')"
    echo ""
    echo "Messaging Configuration:"
    echo "  SNS Topic: $(grep 'sns_topic_name' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')"
    echo "  SQS Queue: $(grep 'sqs_queue_name' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')"
    echo "  Visibility Timeout: $(grep 'sqs_visibility_timeout' terraform.tfvars | cut -d'=' -f2 | tr -d ' ') seconds"
    echo "  Message Retention: $(grep 'sqs_message_retention' terraform.tfvars | cut -d'=' -f2 | tr -d ' ') seconds (4 days)"
    echo "  Long Polling: $(grep 'sqs_receive_wait_time' terraform.tfvars | cut -d'=' -f2 | tr -d ' ') seconds"
fi

echo ""
echo "========================================="
echo "✅ All validations passed!"
echo "========================================="
echo ""
echo "Next Steps:"
echo "  1. Review the configuration above"
echo "  2. Customize terraform.tfvars if needed"
echo "  3. Run: ./deploy.sh"
echo ""
