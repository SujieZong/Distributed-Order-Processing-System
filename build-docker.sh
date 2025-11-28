#!/bin/bash

# Build Docker Image for AWS Fargate (linux/amd64)
# This script ensures the image is built for the correct platform

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get to src directory
cd "$(dirname "$0")/src"

print_info "Building Docker image for linux/amd64 platform..."
print_info "This is required for AWS Fargate deployment"

# Build with explicit platform flag
docker build --platform linux/amd64 -t order-processing-service:latest .

if [ $? -eq 0 ]; then
    print_success "Docker image built successfully!"
    echo ""
    print_info "Image details:"
    docker images order-processing-service:latest
    echo ""
    print_info "To test locally (may not work on ARM Macs):"
    echo "  docker run --rm -p 8080:8080 order-processing-service:latest"
    echo ""
    print_info "To push to ECR:"
    echo "  1. Get ECR URL: export ECR_URL=\$(cd terraform && terraform output -raw ecr_repository_url)"
    echo "  2. Login: aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin \$ECR_URL"
    echo "  3. Tag: docker tag order-processing-service:latest \$ECR_URL:latest"
    echo "  4. Push: docker push \$ECR_URL:latest"
else
    print_error "Docker build failed!"
    exit 1
fi
