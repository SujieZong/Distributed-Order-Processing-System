#!/bin/bash
# deploy.sh
# Complete deployment script for the order processing microservices

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

print_message "======================================" "$BLUE"
print_message "Order Processing Microservices Deployment" "$BLUE"
print_message "======================================" "$BLUE"

# Step 1: Initialize Terraform
print_message "\n[1/6] Initializing Terraform..." "$YELLOW"
terraform init

# Step 2: Validate Terraform configuration
print_message "\n[2/6] Validating Terraform configuration..." "$YELLOW"
terraform validate

# Step 3: Plan infrastructure
print_message "\n[3/6] Planning infrastructure deployment..." "$YELLOW"
terraform plan -out=tfplan

# Step 4: Apply infrastructure
print_message "\n[4/6] Deploying infrastructure..." "$YELLOW"
read -p "Do you want to continue with deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_message "Deployment cancelled." "$RED"
    exit 1
fi

terraform apply tfplan

# Build and push Docker image
print_message "\n[5/6] Building and pushing Docker image..." "$YELLOW"

# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -json deployment_summary | jq -r '.region')
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

print_message "ECR Repository: $ECR_REPO" "$BLUE"

# Login to ECR
print_message "Logging into ECR..." "$YELLOW"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build Docker image (from parent directory)
print_message "Building Docker image..." "$YELLOW"
docker build --platform linux/amd64 -t $ECR_REPO:latest ../src

# Push Docker image
print_message "Pushing Docker image to ECR..." "$YELLOW"
docker push $ECR_REPO:latest

# Step 6: Update ECS services to use new image
print_message "\n[6/6] Updating ECS services..." "$YELLOW"

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
RECEIVER_SERVICE=$(terraform output -raw order_receiver_service_name)
PROCESSOR_SERVICE=$(terraform output -raw order_processor_service_name)

print_message "Updating order-receiver service..." "$YELLOW"
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $RECEIVER_SERVICE \
    --force-new-deployment \
    --region $AWS_REGION > /dev/null

print_message "Updating order-processor service..." "$YELLOW"
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $PROCESSOR_SERVICE \
    --force-new-deployment \
    --region $AWS_REGION > /dev/null

# Wait for services to stabilize
print_message "\nWaiting for services to stabilize (this may take a few minutes)..." "$YELLOW"
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $RECEIVER_SERVICE $PROCESSOR_SERVICE \
    --region $AWS_REGION

# Print deployment summary
print_message "\n======================================" "$GREEN"
print_message "Deployment Successful!" "$GREEN"
print_message "======================================" "$GREEN"

ALB_URL=$(terraform output -raw alb_url)
print_message "\nApplication Load Balancer URL: $ALB_URL" "$BLUE"

print_message "\nTest endpoints:" "$BLUE"
print_message "  Health Check:    curl $ALB_URL/health" "$NC"
print_message "  Sync Orders:     curl -X POST $ALB_URL/orders/sync -H 'Content-Type: application/json' -d @../src/sample_order.json" "$NC"
print_message "  Async Orders:    curl -X POST $ALB_URL/orders/async -H 'Content-Type: application/json' -d @../src/sample_order.json" "$NC"

print_message "\nLoad testing:" "$BLUE"
print_message "  locust -f ../locustfile.py --host=$ALB_URL --users=5 --spawn-rate=1 --run-time=30s --tags sync" "$NC"

print_message "\nView logs:" "$BLUE"
print_message "  aws logs tail $(terraform output -raw order_receiver_log_group) --follow --region $AWS_REGION" "$NC"
print_message "  aws logs tail $(terraform output -raw order_processor_log_group) --follow --region $AWS_REGION" "$NC"

print_message "\n======================================" "$GREEN"
