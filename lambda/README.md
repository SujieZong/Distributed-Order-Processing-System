# Order Processor Lambda Function

AWS Lambda function written in Go that processes orders from SNS events with simulated payment processing.

## Features

- **SNS Event Handler**: Processes orders from SNS topic
- **Payment Processing Simulation**: 3-second delay to simulate payment processing
- **Cold Start Detection**: Tracks and logs cold start events
- **Structured Logging**: Comprehensive logging for CloudWatch
- **Error Handling**: Proper error handling with context awareness
- **Memory Configuration**: 512MB memory allocation
- **Runtime**: Go on provided.al2 (Amazon Linux 2)

## Project Structure

```
lambda/
├── main.go           # Lambda function implementation
├── go.mod            # Go module dependencies
├── Makefile          # Build and deployment automation
└── README.md         # This file
```

## Prerequisites

- Go 1.21 or later
- AWS CLI configured with credentials
- Make utility
- (Optional) AWS SAM CLI for local testing

## Building

### Build for Linux AMD64

```bash
make build
```

This creates a `bootstrap` binary compatible with AWS Lambda provided.al2 runtime.

### Create Deployment Package

```bash
make package
```

This creates `function.zip` containing the bootstrap binary.

## Deployment

### Option 1: Using Terraform (Recommended)

```bash
# First deploy infrastructure
cd ../terraform
terraform apply

# Then update function code
cd ../lambda
make deploy-terraform
```

### Option 2: Using AWS CLI

```bash
# Update existing function
make deploy
```

### Option 3: Manual AWS CLI

```bash
# Build and package
make package

# Update function code
aws lambda update-function-code \
  --function-name order-processor-lambda \
  --zip-file fileb://function.zip \
  --region us-east-1
```

## Local Testing

Test the Lambda function locally using AWS SAM CLI:

```bash
make test-local
```

Or manually:

```bash
# Create test event
cat > test-event.json << EOF
{
  "Records": [
    {
      "EventSource": "aws:sns",
      "Sns": {
        "MessageId": "test-msg-001",
        "Subject": "Order Received",
        "Message": "{\"orderId\":\"ORD-12345\",\"productId\":\"PROD-789\",\"quantity\":3,\"customerId\":\"CUST-456\",\"totalAmount\":149.99,\"timestamp\":\"2024-10-26T10:00:00Z\"}",
        "Timestamp": "2024-10-26T10:00:00.000Z"
      }
    }
  ]
}
EOF

# Test with SAM
sam local invoke -e test-event.json
```

## Viewing Logs

### Tail logs in real-time

```bash
make logs
```

### View logs in AWS Console

1. Navigate to CloudWatch Logs
2. Find log group: `/aws/lambda/order-processor-lambda`
3. View log streams

### Using AWS CLI

```bash
# List recent log streams
aws logs describe-log-streams \
  --log-group-name /aws/lambda/order-processor-lambda \
  --order-by LastEventTime \
  --descending \
  --max-items 5

# Get log events
aws logs get-log-events \
  --log-group-name /aws/lambda/order-processor-lambda \
  --log-stream-name '<stream-name>'
```

## Lambda Function Details

### Handler Function

```go
func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) error
```

### Order Structure

```go
type Order struct {
    OrderID     string  `json:"orderId"`
    ProductID   string  `json:"productId"`
    Quantity    int     `json:"quantity"`
    CustomerID  string  `json:"customerId"`
    TotalAmount float64 `json:"totalAmount"`
    Timestamp   string  `json:"timestamp"`
}
```

### Processing Flow

1. Receive SNS event with one or more records
2. Parse each SNS message to extract Order
3. Log order details
4. Simulate 3-second payment processing
5. Log processing results including:
   - Cold start status
   - Processing time
   - Order details
   - Metrics for CloudWatch

### Cold Start Detection

The function tracks cold starts using a global variable:

- First invocation: `coldStart = true`
- Subsequent invocations in same container: `coldStart = false`

### Logging Format

```
ORDER_PROCESSOR: 2024/10/26 10:00:00.123456 Lambda function invoked. Cold start: true, Startup time: 123.456ms
ORDER_PROCESSOR: 2024/10/26 10:00:00.234567 Processing 1 SNS records
ORDER_PROCESSOR: 2024/10/26 10:00:00.345678 Record 0 - Order received: OrderID=ORD-12345, ProductID=PROD-789, ...
ORDER_PROCESSOR: 2024/10/26 10:00:03.456789 Record 0 - Payment processing completed: {...}
ORDER_PROCESSOR: 2024/10/26 10:00:03.567890 Record 0 - METRICS: OrderID=ORD-12345, ProcessingTime=3.123s, ColdStart=true, Amount=149.99
```

## Makefile Targets

| Target             | Description                           |
| ------------------ | ------------------------------------- |
| `build`            | Build Lambda function for Linux AMD64 |
| `package`          | Create deployment package (zip)       |
| `deploy`           | Deploy using AWS CLI                  |
| `deploy-terraform` | Deploy using Terraform                |
| `test-local`       | Test locally with AWS SAM CLI         |
| `clean`            | Remove build artifacts                |
| `info`             | Get Lambda function information       |
| `logs`             | Tail CloudWatch logs                  |
| `deps`             | Download and tidy dependencies        |
| `help`             | Show help message                     |

## Configuration

### Environment Variables (Set by Lambda)

- `AWS_REGION`: AWS region
- `AWS_LAMBDA_FUNCTION_NAME`: Function name
- `AWS_LAMBDA_FUNCTION_VERSION`: Function version
- `AWS_LAMBDA_FUNCTION_MEMORY_SIZE`: Memory limit (512 MB)

### Lambda Settings

- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **Runtime**: provided.al2 (Amazon Linux 2)
- **Architecture**: x86_64 (AMD64)

## Error Handling

The function implements comprehensive error handling:

- JSON unmarshaling errors
- Context timeout detection
- Graceful error logging
- Continues processing remaining records on individual failures

## Monitoring

### CloudWatch Metrics

- Invocations
- Duration
- Errors
- Throttles
- Concurrent Executions

### Custom Metrics in Logs

```
METRICS: OrderID=XXX, ProcessingTime=X.XXXs, ColdStart=true/false, Amount=XX.XX
```

## Troubleshooting

### Function not found

```bash
# Check if function exists
aws lambda list-functions --region us-east-1 | grep order-processor-lambda

# Create with Terraform first
cd ../terraform && terraform apply
```

### Build fails

```bash
# Install dependencies
make deps

# Clean and rebuild
make clean build
```

### Deployment fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify function exists
aws lambda get-function --function-name order-processor-lambda --region us-east-1
```

### No logs appearing

```bash
# Check CloudWatch log group exists
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/order-processor

# Verify IAM permissions for CloudWatch Logs
```

## Clean Up

```bash
# Remove build artifacts
make clean

# Remove Lambda function (via Terraform)
cd ../terraform && terraform destroy
```

## Development

### Add dependencies

```bash
# Add a new dependency
go get github.com/example/package

# Update go.mod and go.sum
make deps
```

### Code changes workflow

```bash
# 1. Make changes to main.go
# 2. Build and test locally
make build
make test-local

# 3. Deploy
make deploy
```

## Production Considerations

1. **Error Handling**: Implement DLQ for failed messages
2. **Monitoring**: Set up CloudWatch alarms for errors/throttling
3. **Concurrency**: Configure reserved concurrency if needed
4. **Timeout**: Adjust based on actual processing time
5. **Memory**: Monitor and adjust based on actual usage
6. **Retries**: Configure SNS retry policy
7. **Idempotency**: Implement idempotency for order processing
8. **Logging**: Consider structured logging (JSON) for better parsing

## Resources

- [AWS Lambda Go Documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html)
- [AWS Lambda Go SDK](https://github.com/aws/aws-lambda-go)
- [SNS Event Structure](https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html)
