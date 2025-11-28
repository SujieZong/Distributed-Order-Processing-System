.PHONY: build clean deploy package test

# Variables
FUNCTION_NAME = order-processor-lambda
HANDLER = bootstrap
PACKAGE = function.zip
RUNTIME = provided.al2
MEMORY = 512
TIMEOUT = 30
REGION = us-west-2

# Build the Lambda function for Linux AMD64
build:
	@echo "Building Lambda function for Linux AMD64..."
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -tags lambda.norpc -o $(HANDLER) main.go
	@echo "Build complete: $(HANDLER)"

# Create deployment package
package: build
	@echo "Creating deployment package..."
	zip -j $(PACKAGE) $(HANDLER)
	@echo "Deployment package created: $(PACKAGE)"

# Deploy Lambda function using AWS CLI
deploy: package
	@echo "Deploying Lambda function..."
	@if aws lambda get-function --function-name $(FUNCTION_NAME) --region $(REGION) 2>/dev/null; then \
		echo "Updating existing Lambda function..."; \
		aws lambda update-function-code \
			--function-name $(FUNCTION_NAME) \
			--zip-file fileb://$(PACKAGE) \
			--region $(REGION); \
		echo "Waiting for update to complete..."; \
		aws lambda wait function-updated --function-name $(FUNCTION_NAME) --region $(REGION); \
		echo "Lambda function updated successfully"; \
	else \
		echo "Function does not exist. Please create it using Terraform first."; \
		exit 1; \
	fi

# Deploy using Terraform (assumes Terraform is configured)
deploy-terraform: package
	@echo "Deploying with Terraform..."
	cd ../terraform && terraform apply -auto-approve
	@echo "Terraform deployment complete"

# Test the Lambda function locally (requires AWS SAM CLI)
test-local: build
	@echo "Testing Lambda function locally..."
	@echo '{"Records":[{"EventSource":"aws:sns","Sns":{"Message":"{\"orderId\":\"test-001\",\"productId\":\"PROD-123\",\"quantity\":2,\"customerId\":\"CUST-456\",\"totalAmount\":99.99,\"timestamp\":\"2024-10-26T10:00:00Z\"}"}}]}' > test-event.json
	sam local invoke -e test-event.json
	@rm -f test-event.json

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(HANDLER) $(PACKAGE)
	@echo "Clean complete"

# Get Lambda function info
info:
	@echo "Getting Lambda function information..."
	aws lambda get-function --function-name $(FUNCTION_NAME) --region $(REGION)

# Get Lambda function logs
logs:
	@echo "Fetching recent logs..."
	aws logs tail /aws/lambda/$(FUNCTION_NAME) --follow --region $(REGION)

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy
	@echo "Dependencies updated"

# Help target
help:
	@echo "Available targets:"
	@echo "  build           - Build the Lambda function for Linux AMD64"
	@echo "  package         - Create deployment package (zip)"
	@echo "  deploy          - Deploy using AWS CLI (update existing function)"
	@echo "  deploy-terraform- Deploy using Terraform"
	@echo "  test-local      - Test locally using AWS SAM CLI"
	@echo "  clean           - Remove build artifacts"
	@echo "  info            - Get Lambda function information"
	@echo "  logs            - Tail CloudWatch logs"
	@echo "  deps            - Download and tidy dependencies"
	@echo "  help            - Show this help message"
