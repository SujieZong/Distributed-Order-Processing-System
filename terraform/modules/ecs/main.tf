# modules/ecs/main.tf
# ECS cluster and service configurations

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_ecs_task_definition" "order_receiver" {
  family                   = "${var.project_name}-order-receiver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "order-receiver"
      image = var.ecr_image_url
      
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
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = var.sns_topic_arn
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.order_receiver_log_group
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
    Name = "${var.project_name}-order-receiver"
  }
}

resource "aws_ecs_service" "order_receiver" {
  name            = "${var.project_name}-order-receiver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_receiver.arn
  desired_count   = var.order_receiver_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.order_receiver_target_group_arn
    container_name   = "order-receiver"
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [var.order_receiver_target_group_arn]

  tags = {
    Name = "${var.project_name}-order-receiver-service"
  }
}

# Order Processor Task Definition
resource "aws_ecs_task_definition" "order_processor" {
  family                   = "${var.project_name}-order-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "order-processor"
      image = var.ecr_image_url
      
      # No port mappings needed for processor (doesn't serve HTTP)
      portMappings = []

      environment = [
        {
          name  = "SERVICE_MODE"
          value = "processor"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "NUM_WORKERS"
          value = tostring(var.num_workers)
        },
        {
          name  = "PAYMENT_CONCURRENT_LIMIT"
          value = "5"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.order_processor_log_group
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-order-processor"
  }
}

# Order Processor Service
resource "aws_ecs_service" "order_processor" {
  name            = "${var.project_name}-order-processor"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_processor.arn
  desired_count   = var.order_processor_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  # No load balancer for processor (doesn't serve HTTP traffic)

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "${var.project_name}-order-processor-service"
  }
}