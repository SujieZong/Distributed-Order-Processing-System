# modules/logging/outputs.tf

output "order_receiver_log_group_name" {
  description = "Name of the order receiver log group"
  value       = aws_cloudwatch_log_group.order_receiver.name
}

output "order_processor_log_group_name" {
  description = "Name of the order processor log group"
  value       = aws_cloudwatch_log_group.order_processor.name
}

output "order_receiver_log_group_arn" {
  description = "ARN of the order receiver log group"
  value       = aws_cloudwatch_log_group.order_receiver.arn
}

output "order_processor_log_group_arn" {
  description = "ARN of the order processor log group"
  value       = aws_cloudwatch_log_group.order_processor.arn
}
