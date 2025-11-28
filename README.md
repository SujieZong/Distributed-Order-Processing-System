# Distributed Order Processing System

A production-ready, cloud-native order processing system built with microservices architecture on AWS. This project demonstrates scalable, event-driven design using ECS Fargate, AWS Lambda, SNS/SQS messaging, and comprehensive load testing capabilities.

## 🎯 Project Overview

This system implements a distributed order processing pipeline with both synchronous and asynchronous processing modes, designed to handle high-throughput scenarios like flash sales while maintaining reliability and observability.

### Key Features

- **Microservices Architecture**: Containerized services on ECS Fargate
- **Event-Driven Design**: SNS/SQS for asynchronous message processing
- **Serverless Processing**: AWS Lambda for on-demand order processing
- **Load Balancing**: Application Load Balancer with health checks
- **Infrastructure as Code**: Complete Terraform configuration with modular design
- **Load Testing**: Comprehensive Locust-based load testing suite
- **High Availability**: Multi-AZ deployment with auto-scaling capabilities
- **Monitoring**: CloudWatch logs with structured logging

## 📁 Project Structure

```
HW7/
├── src/                          # Order receiver Go application
│   ├── main.go                   # Synchronous order processing API
│   ├── Dockerfile                # Container image definition
│   ├── go.mod                    # Go dependencies
│   └── README.md                 # Service documentation
│
├── lambda/                       # AWS Lambda function
│   ├── main.go                   # Async order processor (Go)
│   ├── Makefile                  # Build automation
│   ├── go.mod                    # Lambda dependencies
│   └── README.md                 # Lambda documentation
│
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Provider configuration
│   ├── variables.tf              # Input variables
│   ├── vpc.tf                    # VPC, subnets, NAT gateway
│   ├── alb.tf                    # Application Load Balancer
│   ├── ecs.tf                    # ECS cluster and services
│   ├── lambda.tf                 # Lambda function config
│   ├── sns_sqs.tf                # Messaging infrastructure
│   ├── outputs.tf                # Output values
│   ├── modules/                  # Reusable Terraform modules
│   ├── deploy.sh                 # Infrastructure deployment
│   └── README.md                 # Detailed infrastructure docs
│
├── reports/                      # Load test results (HTML/CSV)
├── locustfile.py                 # Load testing scenarios
├── locust_config.py              # Load test configuration
├── demo_load_test.py             # Demo load test script
├── requirements.txt              # Python dependencies
├── build-docker.sh               # Docker image build script
├── deploy.sh                     # Main deployment script
├── deploy_lambda.sh              # Lambda deployment script
├── cleanup.sh                    # Cleanup resources script
├── monitor_queue.sh              # SQS queue monitoring
├── verify_setup.sh               # Setup verification
└── README.md                     # This file
```

## 🏗️ Architecture

### System Components

#### 1. Order Receiver Service (ECS Fargate)

- **Endpoint**: `POST /orders/sync`
- **Purpose**: Handles synchronous order processing
- **Features**:
  - Payment verification with 3-second delay
  - Buffered channel pattern for throughput control
  - Health check endpoint at `/health`
- **Scaling**: Auto-scales based on CPU/memory utilization
- **Resources**: 256 CPU units, 512MB memory per task

#### 2. Order Processor Service (ECS Fargate)

- **Endpoint**: `POST /orders/async`
- **Purpose**: Handles asynchronous order submission
- **Features**:
  - Publishes orders to SNS topic
  - Immediate response to client
  - Decoupled from payment processing
- **Scaling**: Auto-scales independently
- **Resources**: 256 CPU units, 512MB memory per task

#### 3. Lambda Order Processor

- **Trigger**: SNS events from order-processing-events topic
- **Purpose**: Serverless payment processing
- **Features**:
  - Concurrent execution
  - Cold start optimization
  - 3-second payment simulation
  - Dead letter queue for failures
- **Configuration**: 512MB memory, 30-second timeout

### Infrastructure Components

#### Networking

- **VPC**: `10.0.0.0/16` CIDR block
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24` (ALB)
- **Private Subnets**: `10.0.10.0/24`, `10.0.11.0/24` (ECS/Lambda)
- **Availability Zones**: Multi-AZ deployment for HA
- **NAT Gateway**: Enables private subnet internet access
- **Internet Gateway**: Public subnet connectivity

#### Load Balancing

- **ALB**: Internet-facing Application Load Balancer
- **Target Groups**:
  - Order Receiver (port 8080)
  - Order Processor (port 8080)
- **Health Checks**: `/health` endpoint with 30s interval
- **Sticky Sessions**: Disabled for stateless design

#### Messaging

- **SNS Topic**: `order-processing-events`
  - Publishes order events
  - Subscribers: SQS queue and Lambda
- **SQS Queue**: `order-processing-queue`
  - Visibility timeout: 30 seconds
  - Message retention: 4 days
  - Dead Letter Queue: Max 3 receive attempts
  - Long polling: 20 seconds

#### Security

- **Security Groups**:
  - ALB: HTTP/HTTPS from internet
  - ECS: Traffic from ALB only
  - Lambda: Outbound to SNS/SQS
- **IAM Roles**:
  - ECS Task Execution: Pull images, write logs
  - ECS Task: Publish to SNS
  - Lambda: Process SQS, write logs

### Request Flow

#### Synchronous Flow

```
Client → ALB → Order Receiver (ECS) → Payment Processing → Response
```

#### Asynchronous Flow

```
Client → ALB → Order Processor (ECS) → SNS Topic → Lambda → Payment Processing
                                            ↓
                                        SQS Queue
```

## 🚀 Getting Started

### Prerequisites

- **AWS Account**: With appropriate permissions
- **AWS CLI**: Configured with credentials
- **Terraform**: v1.0+ installed
- **Docker**: For local development and image building
- **Go**: v1.21+ for local development
- **Python**: v3.8+ for load testing
- **Make**: For build automation

### Installation

1. **Clone the repository**

```bash
git clone <repository-url>
cd HW7
```

2. **Configure AWS credentials**

```bash
aws configure
```

3. **Set up Terraform variables**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

4. **Install Python dependencies**

```bash
pip install -r requirements.txt
```

### Deployment

#### Option 1: Automated Deployment (Recommended)

Deploy everything with a single script:

```bash
./deploy.sh
```

This script will:

1. Build and push Docker images to ECR
2. Deploy infrastructure with Terraform
3. Deploy Lambda function
4. Verify deployment
5. Display service endpoints

#### Option 2: Manual Step-by-Step Deployment

1. **Build Docker image**

```bash
./build-docker.sh
```

2. **Deploy infrastructure**

```bash
cd terraform
./deploy.sh
cd ..
```

3. **Deploy Lambda function**

```bash
./deploy_lambda.sh
```

4. **Verify setup**

```bash
./verify_setup.sh
```

### Accessing the Services

After deployment, get the ALB DNS name:

```bash
cd terraform
terraform output alb_dns_name
```

Test the endpoints:

```bash
# Synchronous processing
curl -X POST http://<ALB_DNS>/orders/sync \
  -H "Content-Type: application/json" \
  -d @src/sample_order.json

# Asynchronous processing
curl -X POST http://<ALB_DNS>/orders/async \
  -H "Content-Type: application/json" \
  -d @src/sample_order.json

# Health check
curl http://<ALB_DNS>/health
```

## 📊 Load Testing

### Running Load Tests

The project includes comprehensive load testing using Locust:

```bash
# Run all load test scenarios
./run_load_tests.sh

# Run specific scenario
locust -f locustfile.py --config locust_config.py \
  --host http://<ALB_DNS> \
  --users 100 --spawn-rate 10 --run-time 5m
```

### Load Test Scenarios

1. **Normal Operations**: Steady load (50-100 users)
2. **Flash Sale**: Burst traffic (500-1000 users, 50/s spawn rate)
3. **Async Processing**: Heavy async load testing
4. **Mixed Workload**: 70% sync, 30% async

### Viewing Results

Load test reports are saved in the `reports/` directory:

- HTML reports with charts and statistics
- CSV files with detailed metrics
- Real-time web UI at `http://localhost:8089` during tests

## 📈 Monitoring

### CloudWatch Logs

View logs for each component:

```bash
# ECS logs
aws logs tail /ecs/order-receiver --follow
aws logs tail /ecs/order-processor --follow

# Lambda logs
aws logs tail /aws/lambda/order-processor --follow
```

### Queue Monitoring

Monitor SQS queue metrics:

```bash
./monitor_queue.sh
```

This displays:

- Messages available
- Messages in flight
- Messages in dead letter queue
- Approximate age of oldest message

### Metrics

Key CloudWatch metrics to monitor:

- **ECS**: CPU/memory utilization, task count
- **ALB**: Request count, target response time, HTTP errors
- **Lambda**: Invocations, duration, errors, throttles
- **SQS**: Messages sent/received, queue depth

## 🛠️ Development

### Local Development

Run the order receiver locally:

```bash
cd src
go mod download
go run main.go
```

Run the Lambda function locally with SAM:

```bash
cd lambda
sam local start-lambda
```

### Testing

```bash
# Test order receiver
cd src
./test_order_api.sh

# Test Lambda
cd lambda
make test
```

### Building

```bash
# Build order receiver
cd src
docker build -t order-receiver .

# Build Lambda
cd lambda
make build
```

## 🧹 Cleanup

To destroy all AWS resources:

```bash
./cleanup.sh
```

Or manually:

```bash
# Delete Lambda
aws lambda delete-function --function-name order-processor

# Destroy Terraform resources
cd terraform
terraform destroy
```

**Warning**: This will delete all resources including logs and data.

## 📖 Additional Documentation

- **Infrastructure Details**: See `terraform/README.md`
- **Order Receiver Service**: See `src/README.md`
- **Lambda Function**: See `lambda/README.md`
- **Terraform Modules**: See `terraform/modules/README.md`

## 🔧 Configuration

### Environment Variables

#### Order Receiver (src/main.go)

- `PORT`: Server port (default: 8080)
- `PAYMENT_QUEUE_SIZE`: Payment buffer size (default: 100)
- `PAYMENT_WORKERS`: Worker count (default: 5)
- `SNS_TOPIC_ARN`: SNS topic for async processing
- `GIN_MODE`: Gin framework mode (release/debug)

#### Lambda Function

- `AWS_REGION`: AWS region for SDK
- Memory: 512MB
- Timeout: 30 seconds

### Terraform Variables

Key variables in `terraform/terraform.tfvars`:

- `aws_region`: AWS region (default: us-east-1)
- `project_name`: Project identifier
- `environment`: Environment tag (dev/staging/prod)
- `ecs_task_count`: Number of ECS tasks per service
- `ecr_repository_url`: ECR repository for Docker images

## 🎓 Architecture Decisions

### Why ECS Fargate?

- Serverless container orchestration
- No EC2 instance management
- Pay only for resources used
- Automatic scaling and availability

### Why SNS + SQS?

- Decoupling of services
- At-least-once delivery guarantee
- Dead letter queue for failure handling
- Multiple subscribers support

### Why Lambda for Async Processing?

- Pay per request (cost-effective for variable load)
- Automatic scaling to 1000 concurrent executions
- No infrastructure management
- Ideal for event-driven workloads

### Why Buffered Channels in Go?

- Natural backpressure mechanism
- Simulates realistic payment gateway limits
- Prevents overwhelming downstream services
- Simple concurrency control

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly (including load tests)
4. Update documentation
5. Submit a pull request

## 📝 License

This project is part of NEU CS6650 Distributed Systems course assignment.

## 👥 Authors

- Sujie Zong
- Xinghang Tong
- Shixing Mao

## 🆘 Troubleshooting

### Common Issues

1. **Terraform fails**: Ensure AWS credentials are configured
2. **Docker build fails**: Check Docker daemon is running
3. **Load tests fail**: Verify ALB DNS is correct and services are healthy
4. **Lambda errors**: Check CloudWatch logs for detailed error messages
5. **High latency**: Monitor ECS task counts and consider increasing capacity

### Support

For issues or questions:

1. Check the detailed documentation in subdirectories
2. Review CloudWatch logs
3. Verify security groups and IAM roles
4. Check AWS service quotas

## 📚 References

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [AWS Lambda with Go](https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Locust Load Testing](https://docs.locust.io/)
- [Go Gin Framework](https://gin-gonic.com/docs/)
