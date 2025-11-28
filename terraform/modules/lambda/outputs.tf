# modules/lambda/outputs.tf
# Output values for Lambda module

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.order_processor.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.order_processor.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.order_processor.invoke_arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_log_group.arn
}

output "sns_subscription_arn" {
  description = "ARN of the SNS subscription"
  value       = aws_sns_topic_subscription.lambda_subscription.arn
}
