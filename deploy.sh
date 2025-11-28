#!/bin/bash

# Complete Deployment Script for Order Processing Service
# Region: us-west-2

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-west-2"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SRC_DIR="$PROJECT_ROOT/src"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Order Processing Service Deployment${NC}"
echo -e "${BLUE}Region: $AWS_REGION${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Step 1: Verify AWS credentials
echo -e "${YELLOW}Step 1: Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured!${NC}"
    echo "Please configure your AWS credentials and try again."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# Step 2: Initialize and apply Terraform
echo -e "${YELLOW}Step 2: Deploying infrastructure with Terraform...${NC}"
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan
echo "Generating Terraform plan..."
terraform plan -out=tfplan

# Apply
echo "Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
ECR_REPO=$(terraform output -raw ecr_repository_url)
ALB_DNS=$(terraform output -raw alb_dns_name)

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "  ECR Repository: $ECR_REPO"
echo -e "  ALB DNS: $ALB_DNS"
echo ""

# Step 3: Build and push Docker image
echo -e "${YELLOW}Step 3: Building and pushing Docker image...${NC}"
cd "$SRC_DIR"

# Build Docker image
echo "Building Docker image for linux/amd64 platform..."
docker build --platform linux/amd64 -t order-api:latest .

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag and push
echo "Tagging and pushing image to ECR..."
docker tag order-api:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"
echo ""

# Step 4: Wait for ECS service to start
echo -e "${YELLOW}Step 4: Waiting for ECS service to start...${NC}"
echo "This may take 2-3 minutes..."

MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    RUNNING_COUNT=$(aws ecs describe-services \
        --region $AWS_REGION \
        --cluster order-processing-cluster \
        --services order-receiver \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    DESIRED_COUNT=$(aws ecs describe-services \
        --region $AWS_REGION \
        --cluster order-processing-cluster \
        --services order-receiver \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null || echo "0")
    
    echo "  Running tasks: $RUNNING_COUNT / $DESIRED_COUNT"
    
    if [ "$RUNNING_COUNT" == "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" != "0" ]; then
        echo -e "${GREEN}✓ ECS service is running${NC}"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${RED}Warning: Timeout waiting for ECS service to start${NC}"
    echo "Please check the ECS console for details."
fi
echo ""

# Step 5: Test the deployment
echo -e "${YELLOW}Step 5: Testing the deployment...${NC}"

# Wait a bit for ALB to register targets
echo "Waiting for ALB to register healthy targets (30 seconds)..."
sleep 30

# Test health endpoint
echo "Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health || echo "000")

if [ "$HEALTH_RESPONSE" == "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${YELLOW}⚠ Health check returned: $HEALTH_RESPONSE${NC}"
    echo "The service may still be starting up. Please wait a minute and try again."
fi

# Test sync order endpoint
echo "Testing /orders/sync endpoint..."
SYNC_RESPONSE=$(curl -s -X POST http://$ALB_DNS/orders/sync \
    -H "Content-Type: application/json" \
    -d '{
        "customer_id": "test-customer-123",
        "items": [
            {"product_id": "prod-1", "quantity": 2, "price": 29.99}
        ],
        "total_amount": 59.98
    }' || echo "ERROR")

if [[ "$SYNC_RESPONSE" == *"order_id"* ]]; then
    echo -e "${GREEN}✓ Sync order endpoint working${NC}"
    echo "  Response: $SYNC_RESPONSE"
else
    echo -e "${YELLOW}⚠ Sync order response: $SYNC_RESPONSE${NC}"
fi
echo ""

# Step 6: Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "📋 Deployment Summary:"
echo -e "  AWS Region: ${YELLOW}$AWS_REGION${NC}"
echo -e "  AWS Account: ${YELLOW}$AWS_ACCOUNT_ID${NC}"
echo -e "  ECR Repository: ${YELLOW}$ECR_REPO${NC}"
echo -e "  ALB DNS: ${YELLOW}$ALB_DNS${NC}"
echo ""
echo -e "🧪 Ready for Load Testing:"
echo -e "  Run: ${YELLOW}./run_load_tests.sh${NC}"
echo ""
echo -e "📊 Monitor Logs:"
echo -e "  aws logs tail /ecs/order-receiver --region $AWS_REGION --follow"
echo ""
echo -e "🔗 Test Endpoints:"
echo -e "  Health: ${YELLOW}curl http://$ALB_DNS/health${NC}"
echo -e "  Sync Order: ${YELLOW}curl -X POST http://$ALB_DNS/orders/sync -H 'Content-Type: application/json' -d @src/sample_order.json${NC}"
echo ""

# Save ALB DNS to file for load testing
echo "$ALB_DNS" > "$PROJECT_ROOT/.alb_dns"
echo -e "${GREEN}ALB DNS saved to .alb_dns file${NC}"
echo ""
