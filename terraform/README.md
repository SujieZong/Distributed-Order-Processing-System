# Terraform Infrastructure for Order Processing Microservices

This directory contains the complete Terraform configuration for deploying a production-ready microservices architecture on AWS for order processing.

**Note**: This configuration uses a **modular structure** with separate modules for each component (network, ALB, ECS, messaging, etc.). This improves maintainability, reusability, and organization. See `modules/README.md` for detailed module documentation.

## Architecture Overview

The infrastructure includes:

### Networking

- **VPC**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (for ALB)
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24 (for ECS tasks)
- **NAT Gateway**: For private subnet internet access
- **Internet Gateway**: For public subnet internet access

### Compute

- **ECS Cluster**: Fargate-based cluster
- **Order Receiver Service**: 2 tasks (256 CPU, 512MB memory)
  - Handles synchronous order processing via `/orders/sync`
  - Health check endpoint: `/health`
- **Order Processor Service**: 2 tasks (256 CPU, 512MB memory)
  - Handles asynchronous order processing via `/orders/async`
  - Consumes from SQS queue

### Load Balancing

- **Application Load Balancer** (ALB)
  - Deployed in public subnets
  - Routes `/orders/sync` and `/health` to order-receiver
  - Routes `/orders/async` to order-processor

### Messaging

- **SNS Topic**: `order-processing-events`
  - For publishing order events
- **SQS Queue**: `order-processing-queue`
  - Visibility timeout: 30 seconds
  - Message retention: 4 days (345,600 seconds)
  - Long polling: 20 seconds
  - Dead Letter Queue for failed messages
- **SNS to SQS Subscription**: Automatic message delivery

### Security

- **Security Groups**:
  - ALB SG: Allows HTTP/HTTPS from internet
  - ECS SG: Allows traffic only from ALB on port 8080
- **IAM Roles**: Uses AWS Learner Lab LabRole with permissions for:
  - ECR (pull images)
  - CloudWatch Logs (write logs)
  - SNS (publish messages)
  - SQS (consume messages)

### Monitoring

- **CloudWatch Log Groups**:
  - `/ecs/order-processing/order-receiver`
  - `/ecs/order-processing/order-processor`
  - 7-day retention

## File Structure

```
.
├── main.tf                   # Main configuration - wires together all modules
├── variables.tf              # Input variables
├── terraform.tfvars          # Variable values
├── outputs.tf                # Output values
├── deploy.sh                 # Automated deployment script
├── validate_terraform.sh     # Configuration validation
├── README.md                 # This file
│
├── modules/                  # Reusable Terraform modules
│   ├── README.md            # Module documentation
│   ├── network/             # VPC, subnets, NAT gateway, security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/                 # Application Load Balancer
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/                 # Elastic Container Registry
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs/                 # ECS cluster, task definitions, services
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── logging/             # CloudWatch log groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── messaging/           # SNS topics and SQS queues
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── old_flat_structure/      # Backup of previous flat structure
    ├── vpc.tf
    ├── alb.tf
    ├── ecs.tf
    └── sns_sqs.tf
```

## Prerequisites

1. **AWS CLI** configured with credentials

   ```bash
   aws configure
   ```

2. **Terraform** installed (v1.0+)

   ```bash
   terraform --version
   ```

3. **Docker** installed for building images

   ```bash
   docker --version
   ```

4. **AWS Learner Lab** access with LabRole configured

## Deployment

### Option 1: Automated Deployment (Recommended)

Use the provided deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:

1. Initialize Terraform
2. Validate configuration
3. Plan infrastructure
4. Apply infrastructure (with confirmation)
5. Build Docker image
6. Push to ECR
7. Update ECS services
8. Display deployment summary

### Option 2: Manual Deployment

#### Step 1: Initialize Terraform

```bash
terraform init
```

#### Step 2: Review and customize variables

Edit `terraform.tfvars` if needed:

```bash
vim terraform.tfvars
```

#### Step 3: Plan infrastructure

```bash
terraform plan -out=tfplan
```

#### Step 4: Apply infrastructure

```bash
terraform apply tfplan
```

#### Step 5: Build and push Docker image

```bash
# Get ECR repository URL
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -json deployment_summary | jq -r '.region')

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build and push
docker build --platform linux/amd64 -t $ECR_REPO:latest ./src
docker push $ECR_REPO:latest
```

#### Step 6: Update ECS services

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs update-service --cluster $CLUSTER --service order-receiver --force-new-deployment --region $AWS_REGION
aws ecs update-service --cluster $CLUSTER --service order-processor --force-new-deployment --region $AWS_REGION
```

## Testing

### Get ALB URL

```bash
ALB_URL=$(terraform output -raw alb_url)
echo $ALB_URL
```

### Test Health Endpoint

```bash
curl $ALB_URL/health
```

### Test Sync Order Processing

```bash
curl -X POST $ALB_URL/orders/sync \
  -H 'Content-Type: application/json' \
  -d @src/sample_order.json
```

### Test Async Order Processing

```bash
curl -X POST $ALB_URL/orders/async \
  -H 'Content-Type: application/json' \
  -d @src/sample_order.json
```

### Load Testing with Locust

```bash
# Normal load test
locust -f locustfile.py --host=$ALB_URL \
  --users=5 --spawn-rate=1 --run-time=30s --tags sync

# Flash sale test
locust -f locustfile.py --host=$ALB_URL \
  --users=20 --spawn-rate=10 --run-time=60s --tags async
```

## Monitoring

### View ECS Logs

```bash
# Order Receiver logs
aws logs tail /ecs/order-processing/order-receiver --follow --region us-west-2

# Order Processor logs
aws logs tail /ecs/order-processing/order-processor --follow --region us-west-2
```

### View ECS Service Status

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs describe-services --cluster $CLUSTER --services order-receiver order-processor --region us-west-2
```

### View SQS Queue Metrics

```bash
QUEUE_URL=$(terraform output -raw sqs_queue_url)
aws sqs get-queue-attributes --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --region us-west-2
```

## Updating the Application

### Update Code and Redeploy

```bash
# Build new image
ECR_REPO=$(terraform output -raw ecr_repository_url)
docker build --platform linux/amd64 -t $ECR_REPO:latest ./src
docker push $ECR_REPO:latest

# Force new deployment
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs update-service --cluster $CLUSTER --service order-receiver --force-new-deployment
aws ecs update-service --cluster $CLUSTER --service order-processor --force-new-deployment
```

### Update Infrastructure

```bash
# Modify terraform files as needed
terraform plan
terraform apply
```

## Scaling

### Manual Scaling

Edit `terraform.tfvars`:

```hcl
order_receiver_desired_count  = 4  # Increase from 2 to 4
order_processor_desired_count = 4
```

Then apply:

```bash
terraform apply
```

### Auto-scaling (Optional Enhancement)

Add auto-scaling policies in `ecs.tf`:

```hcl
resource "aws_appautoscaling_target" "order_receiver" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.order_receiver.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "order_receiver_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.order_receiver.resource_id
  scalable_dimension = aws_appautoscaling_target.order_receiver.scalable_dimension
  service_namespace  = aws_appautoscaling_target.order_receiver.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

## Cleanup

### Destroy all resources

```bash
terraform destroy
```

**Warning**: This will delete ALL resources including:

- ECS cluster and services
- ALB and target groups
- VPC and all networking components
- SNS topic and SQS queues
- CloudWatch log groups
- ECR repository (images will be deleted)

## Troubleshooting

### Issue: ECS tasks failing to start

**Check**:

1. ECR image exists: `aws ecr describe-images --repository-name order-processing-service`
2. Task definition: `aws ecs describe-task-definition --task-definition order-processing-order-receiver`
3. CloudWatch logs for error messages

### Issue: ALB returns 503

**Check**:

1. Target group health: AWS Console → EC2 → Target Groups
2. Security group rules allow ALB → ECS communication
3. ECS tasks are running: `aws ecs list-tasks --cluster order-processing-cluster`

### Issue: Cannot push to ECR

**Check**:

1. ECR login: `aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <ecr-url>`
2. IAM permissions for ECR

### Issue: SQS messages not being consumed

**Check**:

1. Queue has messages: Check SQS console
2. Order processor logs for errors
3. IAM role has SQS permissions

## Configuration Details

### Environment Variables (ECS Tasks)

- `PORT`: 8080
- `GIN_MODE`: release
- `PAYMENT_QUEUE_SIZE`: 100
- `PAYMENT_WORKERS`: 5
- `SNS_TOPIC_ARN`: Auto-configured
- `SQS_QUEUE_URL`: Auto-configured (processor only)
- `AWS_REGION`: us-west-2
- `SERVICE_NAME`: order-receiver or order-processor

### Resource Naming Convention

All resources follow the pattern: `{project_name}-{resource_type}`

- Project name: `order-processing`
- Environment: `dev`
- Example: `order-processing-alb`, `order-processing-cluster`

## Cost Estimation

Approximate monthly costs (us-west-2):

- ECS Fargate (4 tasks × 0.25 vCPU × 0.5GB): ~$30
- ALB: ~$20
- NAT Gateway: ~$35
- Data transfer: Variable
- CloudWatch Logs (7-day retention): ~$5

**Total**: ~$90-100/month

## Security Best Practices

1. **Private Subnets**: ECS tasks run in private subnets with no direct internet access
2. **Security Groups**: Principle of least privilege - only ALB can reach ECS tasks
3. **IAM Roles**: Tasks use LabRole with minimal required permissions
4. **Encryption**: Enable encryption at rest for SQS (optional, add to `sns_sqs.tf`)
5. **HTTPS**: Consider adding SSL certificate to ALB for production

## Next Steps

1. **Implement `/orders/async` endpoint** in `main.go` to work with SQS
2. **Add CloudWatch alarms** for monitoring
3. **Enable auto-scaling** based on CPU/memory/queue depth
4. **Add DynamoDB** for order persistence
5. **Implement CI/CD** with GitHub Actions or CodePipeline
6. **Add WAF** rules to ALB for security
7. **Enable X-Ray** for distributed tracing

## Support

For issues or questions:

1. Check CloudWatch Logs
2. Review Terraform state: `terraform show`
3. Validate configuration: `terraform validate`
4. Check AWS service quotas

## License

This infrastructure code is provided as-is for educational purposes.
