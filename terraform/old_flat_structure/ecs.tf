# ecs.tf
# ECS cluster and service configurations

# CloudWatch Log Groups for ECS Tasks
resource "aws_cloudwatch_log_group" "order_receiver" {
  name              = "/ecs/${var.project_name}/order-receiver"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-order-receiver-logs"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-receiver"
  }
}

resource "aws_cloudwatch_log_group" "order_processor" {
  name              = "/ecs/${var.project_name}/order-processor"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-order-processor-logs"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-processor"
  }
}

# ECR Repository
resource "aws_ecr_repository" "main" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = var.ecr_repository_name
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECR Lifecycle Policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Data source to get account ID for LabRole ARN
data "aws_caller_identity" "current" {}

# Local variable for LabRole ARN
locals {
  lab_role_arn = var.lab_role_arn != "" ? var.lab_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS Task Definition for Order Receiver
resource "aws_ecs_task_definition" "order_receiver" {
  family                   = "${var.project_name}-order-receiver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = local.lab_role_arn
  task_role_arn            = local.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "order-receiver"
      image     = "${aws_ecr_repository.main.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "GIN_MODE"
          value = "release"
        },
        {
          name  = "PAYMENT_QUEUE_SIZE"
          value = "100"
        },
        {
          name  = "PAYMENT_WORKERS"
          value = "5"
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = aws_sns_topic.order_processing_events.arn
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SERVICE_NAME"
          value = "order-receiver"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.order_receiver.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-order-receiver-task"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-receiver"
  }
}

# ECS Task Definition for Order Processor
resource "aws_ecs_task_definition" "order_processor" {
  family                   = "${var.project_name}-order-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = local.lab_role_arn
  task_role_arn            = local.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "order-processor"
      image     = "${aws_ecr_repository.main.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "GIN_MODE"
          value = "release"
        },
        {
          name  = "PAYMENT_QUEUE_SIZE"
          value = "100"
        },
        {
          name  = "PAYMENT_WORKERS"
          value = "5"
        },
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.order_processing.url
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = aws_sns_topic.order_processing_events.arn
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SERVICE_NAME"
          value = "order-processor"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.order_processor.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-order-processor-task"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-processor"
  }
}

# ECS Service for Order Receiver
resource "aws_ecs_service" "order_receiver" {
  name            = "order-receiver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_receiver.arn
  desired_count   = var.order_receiver_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order_receiver.arn
    container_name   = "order-receiver"
    container_port   = var.container_port
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  # Wait for ALB listener rules to be created
  depends_on = [
    aws_lb_listener_rule.order_receiver,
    aws_lb_listener.http
  ]

  tags = {
    Name        = "${var.project_name}-order-receiver-service"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-receiver"
  }
}

# ECS Service for Order Processor
resource "aws_ecs_service" "order_processor" {
  name            = "order-processor"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_processor.arn
  desired_count   = var.order_processor_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order_processor.arn
    container_name   = "order-processor"
    container_port   = var.container_port
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  # Wait for ALB listener rules to be created
  depends_on = [
    aws_lb_listener_rule.order_processor,
    aws_lb_listener.http
  ]

  tags = {
    Name        = "${var.project_name}-order-processor-service"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-processor"
  }
}
