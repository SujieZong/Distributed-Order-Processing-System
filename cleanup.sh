#!/bin/bash

# Cleanup Script - Destroy all AWS infrastructure
# Use this to tear down resources and avoid charges

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo -e "${RED}================================================${NC}"
echo -e "${RED}⚠️  INFRASTRUCTURE CLEANUP${NC}"
echo -e "${RED}================================================${NC}"
echo ""
echo -e "${YELLOW}This will destroy ALL deployed AWS resources:${NC}"
echo "  - VPC and all networking components"
echo "  - Application Load Balancer"
echo "  - ECS Cluster and Services"
echo "  - ECR Repository and Docker images"
echo "  - CloudWatch Log Groups"
echo "  - SNS Topics and SQS Queues"
echo ""
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

read -p "Are you sure you want to destroy all resources? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"
cd "$TERRAFORM_DIR"

# Destroy infrastructure
echo "Running terraform destroy..."
terraform destroy -auto-approve

echo ""
echo -e "${GREEN}✓ All infrastructure destroyed${NC}"
echo ""

# Clean up local files
echo -e "${YELLOW}Cleaning up local files...${NC}"

if [ -f "$PROJECT_ROOT/.alb_dns" ]; then
    rm "$PROJECT_ROOT/.alb_dns"
    echo "  Removed .alb_dns"
fi

if [ -f "$TERRAFORM_DIR/tfplan" ]; then
    rm "$TERRAFORM_DIR/tfplan"
    echo "  Removed tfplan"
fi

if [ -d "$PROJECT_ROOT/reports" ]; then
    read -p "Remove test reports directory? (y/n): " remove_reports
    if [ "$remove_reports" = "y" ]; then
        rm -rf "$PROJECT_ROOT/reports"
        echo "  Removed reports/"
    fi
fi

echo ""
echo -e "${GREEN}Cleanup complete!${NC}"
echo ""
