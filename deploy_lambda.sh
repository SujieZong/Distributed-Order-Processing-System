#!/bin/bash
# deploy_lambda.sh
# Deploy Lambda function that subscribes directly to SNS (no SQS)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AWS_REGION="us-west-2"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Lambda Order Processor Deployment${NC}"
echo -e "${BLUE}  (SNS Direct Subscription - No SQS)${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Step 1: Build Lambda function
echo -e "${GREEN}Step 1: Building Lambda function...${NC}"
cd lambda

# Clean previous builds
rm -f bootstrap function.zip

# Build for Lambda (Linux AMD64)
echo "Building Go binary for Linux AMD64..."
GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bootstrap main.go

# Create deployment package
echo "Creating deployment package..."
zip function.zip bootstrap

echo -e "${GREEN}✓ Lambda function built: $(ls -lh function.zip | awk '{print $5}')${NC}"
cd ..
echo ""

# Step 2: Deploy infrastructure with Lambda enabled
echo -e "${GREEN}Step 2: Deploying infrastructure with Lambda...${NC}"
cd terraform

# Initialize Terraform
terraform init

# Apply with Lambda enabled
echo "Deploying SNS topic and Lambda function..."
terraform apply \
  -var="enable_lambda=true" \
  -var="lambda_deployment_package=../lambda/function.zip" \
  -auto-approve

# Get outputs
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)
LAMBDA_FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "order-processor-lambda")
ALB_URL=$(terraform output -raw alb_dns_name)

cd ..

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "  SNS Topic: ${BLUE}$SNS_TOPIC_ARN${NC}"
echo -e "  Lambda Function: ${BLUE}$LAMBDA_FUNCTION_NAME${NC}"
echo -e "  ALB URL: ${BLUE}$ALB_URL${NC}"
echo ""

# Step 3: Verify Lambda subscription
echo -e "${GREEN}Step 3: Verifying Lambda subscription to SNS...${NC}"

SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --region "$AWS_REGION" \
  --query 'Subscriptions[?Protocol==`lambda`]' \
  --output json)

if echo "$SUBSCRIPTIONS" | grep -q "lambda"; then
    echo -e "${GREEN}✓ Lambda is subscribed to SNS topic${NC}"
    echo "$SUBSCRIPTIONS" | jq -r '.[] | "  Endpoint: \(.Endpoint)"'
else
    echo -e "${RED}✗ Lambda subscription not found${NC}"
    exit 1
fi
echo ""

# Step 4: Test Lambda function
echo -e "${GREEN}Step 4: Testing Lambda function...${NC}"
echo ""

# Test with direct invoke
echo "Testing with direct invoke..."
cat > /tmp/test_sns_event.json << 'EOF'
{
  "Records": [
    {
      "EventSource": "aws:sns",
      "EventVersion": "1.0",
      "EventSubscriptionArn": "arn:aws:sns:us-west-2:123456789012:order-processing-events:12345678-1234-1234-1234-123456789012",
      "Sns": {
        "Type": "Notification",
        "MessageId": "test-message-id",
        "TopicArn": "arn:aws:sns:us-west-2:123456789012:order-processing-events",
        "Subject": "Test Order",
        "Message": "{\"orderId\":\"TEST-001\",\"productId\":\"PROD-001\",\"quantity\":2,\"customerId\":\"CUST-123\",\"totalAmount\":99.99,\"timestamp\":\"2024-01-01T00:00:00Z\"}",
        "Timestamp": "2024-01-01T00:00:00.000Z",
        "SignatureVersion": "1",
        "Signature": "test-signature",
        "SigningCertUrl": "https://sns.us-west-2.amazonaws.com/test.pem",
        "UnsubscribeUrl": "https://sns.us-west-2.amazonaws.com/?Action=Unsubscribe",
        "MessageAttributes": {}
      }
    }
  ]
}
EOF

aws lambda invoke \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --payload file:///tmp/test_sns_event.json \
  --region "$AWS_REGION" \
  /tmp/lambda_response.json > /dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lambda invoked successfully${NC}"
    cat /tmp/lambda_response.json
else
    echo -e "${RED}✗ Lambda invocation failed${NC}"
fi
echo ""

# Step 5: Test via SNS publish
echo -e "${GREEN}Step 5: Testing via SNS publish...${NC}"

ORDER_PAYLOAD='{
  "orderId": "SNS-TEST-001",
  "productId": "PROD-002",
  "quantity": 5,
  "customerId": "CUST-456",
  "totalAmount": 149.99,
  "timestamp": "2024-01-01T00:00:00Z"
}'

echo "Publishing test order to SNS..."
MESSAGE_ID=$(aws sns publish \
  --topic-arn "$SNS_TOPIC_ARN" \
  --message "$ORDER_PAYLOAD" \
  --subject "Test Order from Script" \
  --region "$AWS_REGION" \
  --query 'MessageId' \
  --output text)

if [ -n "$MESSAGE_ID" ]; then
    echo -e "${GREEN}✓ Message published to SNS${NC}"
    echo -e "  Message ID: ${BLUE}$MESSAGE_ID${NC}"
else
    echo -e "${RED}✗ Failed to publish message${NC}"
    exit 1
fi
echo ""

# Wait for Lambda to process
echo "Waiting 5 seconds for Lambda to process..."
sleep 5

# Step 6: Check Lambda logs
echo -e "${GREEN}Step 6: Checking Lambda logs...${NC}"
echo ""

aws logs tail "/aws/lambda/$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --since 2m \
  --format short | tail -20

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${YELLOW}Lambda Configuration:${NC}"
echo "  • Function: $LAMBDA_FUNCTION_NAME"
echo "  • SNS Topic: $SNS_TOPIC_ARN"
echo "  • Subscription: Lambda directly to SNS (no SQS)"
echo "  • Payment Delay: 3 seconds"
echo "  • Timeout: 30 seconds"
echo ""
echo -e "${YELLOW}Test Commands:${NC}"
echo ""
echo "1. Test via async endpoint (publishes to SNS → triggers Lambda):"
echo "   ${GREEN}curl -X POST http://$ALB_URL/orders/async \\${NC}"
echo "   ${GREEN}  -H 'Content-Type: application/json' \\${NC}"
echo "   ${GREEN}  -d @src/sample_order.json${NC}"
echo ""
echo "2. Watch Lambda logs in real-time:"
echo "   ${GREEN}aws logs tail /aws/lambda/$LAMBDA_FUNCTION_NAME --follow --region $AWS_REGION${NC}"
echo ""
echo "3. Test Lambda directly:"
echo "   ${GREEN}./test-lambda.sh${NC}"
echo ""
echo "4. Run load test (Lambda will process async orders):"
echo "   ${GREEN}./test-lambda-load.sh${NC}"
echo ""
