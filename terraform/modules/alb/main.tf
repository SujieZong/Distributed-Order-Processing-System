# modules/alb/main.tf
# Application Load Balancer configuration

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for Order Receiver Service
resource "aws_lb_target_group" "order_receiver" {
  name        = "${var.project_name}-receiver-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${var.project_name}-receiver-tg"
    Service = "order-receiver"
  }
}

# Target Group for Order Processor Service
resource "aws_lb_target_group" "order_processor" {
  name        = "${var.project_name}-processor-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${var.project_name}-processor-tg"
    Service = "order-processor"
  }
}

# ALB Listener (HTTP on port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Forward all traffic to order receiver by default
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_receiver.arn
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}

# Listener Rule for Order Receiver - /orders/sync, /orders/async and /health
resource "aws_lb_listener_rule" "order_receiver" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_receiver.arn
  }

  condition {
    path_pattern {
      values = ["/orders/sync", "/orders/async", "/health"]
    }
  }

  tags = {
    Name = "${var.project_name}-receiver-rule"
  }
}

# Order Processor doesn't need ALB rules (doesn't serve HTTP traffic)
# It only polls SQS queue in the background
