# Terraform Modules

This directory contains reusable Terraform modules for the order processing microservices infrastructure.

## Module Structure

```
modules/
├── network/        # VPC, subnets, NAT gateway, security groups
├── alb/            # Application Load Balancer and target groups
├── ecr/            # Elastic Container Registry
├── ecs/            # ECS cluster, task definitions, and services
├── logging/        # CloudWatch log groups
└── messaging/      # SNS topics and SQS queues
```

## Modules

### network

**Purpose**: Creates VPC, subnets, NAT gateway, and security groups

**Resources**:

- VPC (10.0.0.0/16)
- 2 public subnets (10.0.1.0/24, 10.0.2.0/24)
- 2 private subnets (10.0.10.0/24, 10.0.11.0/24)
- Internet Gateway
- NAT Gateway with Elastic IP
- Route tables and associations
- Security groups for ALB and ECS tasks

**Outputs**:

- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`
- `alb_security_group_id`
- `ecs_security_group_id`
- `nat_gateway_ip`

### alb

**Purpose**: Creates Application Load Balancer with routing rules

**Resources**:

- Application Load Balancer
- Target groups for order-receiver and order-processor
- HTTP listener on port 80
- Listener rules for path-based routing

**Outputs**:

- `alb_dns_name`
- `alb_arn`
- `order_receiver_target_group_arn`
- `order_processor_target_group_arn`

### ecr

**Purpose**: Creates ECR repository for Docker images

**Resources**:

- ECR repository
- Lifecycle policy (keep last 5 images)

**Outputs**:

- `repository_url`
- `repository_name`
- `repository_arn`

### ecs

**Purpose**: Creates ECS cluster and services

**Resources**:

- ECS Fargate cluster
- Task definitions for order-receiver and order-processor
- ECS services with load balancer integration

**Outputs**:

- `cluster_name`
- `cluster_arn`
- `order_receiver_service_name`
- `order_processor_service_name`

### logging

**Purpose**: Creates CloudWatch log groups

**Resources**:

- Log group for order-receiver
- Log group for order-processor

**Outputs**:

- `order_receiver_log_group_name`
- `order_processor_log_group_name`

### messaging

**Purpose**: Creates SNS topic and SQS queue with subscription

**Resources**:

- SNS topic (order-processing-events)
- SQS queue (order-processing-queue)
- SQS dead letter queue
- SNS to SQS subscription
- SQS queue policy

**Outputs**:

- `sns_topic_arn`
- `sqs_queue_url`
- `sqs_queue_arn`
- `sqs_dlq_url`

## Module Dependencies

```
network
  ↓
alb ← depends on network (vpc_id, public_subnet_ids, security_group)
  ↓
ecs ← depends on network, alb, logging, messaging, ecr
```

## Usage

Modules are called from the root `main.tf`:

```hcl
module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  container_port       = var.container_port
}

module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  container_port        = var.container_port
}

# ... other modules
```

## Benefits of Modular Structure

1. **Reusability**: Modules can be reused across different environments
2. **Maintainability**: Changes are isolated to specific modules
3. **Testing**: Each module can be tested independently
4. **Organization**: Clear separation of concerns
5. **Scalability**: Easy to add new services or components

## Customization

Each module has its own `variables.tf` file. Customize by:

1. Modifying default values in module's `variables.tf`
2. Passing different values from root `main.tf`
3. Using `terraform.tfvars` for environment-specific values

## Adding New Modules

To add a new module:

1. Create directory: `mkdir modules/new-module`
2. Create files:
   - `main.tf` - Resource definitions
   - `variables.tf` - Input variables
   - `outputs.tf` - Output values
3. Call from root `main.tf`
4. Wire outputs to other modules as needed
