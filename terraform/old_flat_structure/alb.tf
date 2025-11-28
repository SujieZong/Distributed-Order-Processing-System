# alb.tf
# Application Load Balancer configuration

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group for Order Receiver Service
resource "aws_lb_target_group" "order_receiver" {
  name        = "${var.project_name}-receiver-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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
    Name        = "${var.project_name}-receiver-tg"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-receiver"
  }
}

# Target Group for Order Processor Service
resource "aws_lb_target_group" "order_processor" {
  name        = "${var.project_name}-processor-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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
    Name        = "${var.project_name}-processor-tg"
    Environment = var.environment
    Project     = var.project_name
    Service     = "order-processor"
  }
}

# ALB Listener (HTTP on port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "NOT_FOUND"
        message = "No matching route found"
      })
      status_code = "404"
    }
  }

  tags = {
    Name        = "${var.project_name}-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener Rule for Order Receiver - /orders/sync and /health
resource "aws_lb_listener_rule" "order_receiver" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_receiver.arn
  }

  condition {
    path_pattern {
      values = ["/orders/sync", "/health"]
    }
  }

  tags = {
    Name        = "${var.project_name}-receiver-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener Rule for Order Processor - /orders/async
resource "aws_lb_listener_rule" "order_processor" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_processor.arn
  }

  condition {
    path_pattern {
      values = ["/orders/async"]
    }
  }

  tags = {
    Name        = "${var.project_name}-processor-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}
