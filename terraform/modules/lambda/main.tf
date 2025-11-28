# modules/lambda/main.tf
# Lambda function for order processing

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.function_name}-logs"
  }
}

# Lambda Function
resource "aws_lambda_function" "order_processor" {
  function_name = var.function_name
  role          = var.execution_role_arn
  handler       = "bootstrap"  # For Go custom runtime
  runtime       = var.runtime
  memory_size   = var.memory_size
  timeout       = var.timeout
  architectures = ["x86_64"]

  # Deployment package
  filename         = var.deployment_package_path
  source_code_hash = filebase64sha256(var.deployment_package_path)

  environment {
    variables = {
      LOG_LEVEL = var.log_level
    }
  }

  # Ensure log group exists before Lambda
  depends_on = [aws_cloudwatch_log_group.lambda_log_group]

  tags = {
    Name = var.function_name
  }
}

# SNS Topic Subscription for Lambda
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.order_processor.arn
}

# Lambda Permission for SNS to invoke the function
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

# CloudWatch Log Stream (optional, auto-created by Lambda)
resource "aws_cloudwatch_log_stream" "lambda_stream" {
  name           = "lambda-stream"
  log_group_name = aws_cloudwatch_log_group.lambda_log_group.name

  depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}
