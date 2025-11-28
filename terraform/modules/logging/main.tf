# modules/logging/main.tf
# CloudWatch log groups for ECS tasks

resource "aws_cloudwatch_log_group" "order_receiver" {
  name              = "/ecs/${var.project_name}/order-receiver"
  retention_in_days = var.retention_in_days

  tags = {
    Name    = "${var.project_name}-order-receiver-logs"
    Service = "order-receiver"
  }
}

resource "aws_cloudwatch_log_group" "order_processor" {
  name              = "/ecs/${var.project_name}/order-processor"
  retention_in_days = var.retention_in_days

  tags = {
    Name    = "${var.project_name}-order-processor-logs"
    Service = "order-processor"
  }
}
