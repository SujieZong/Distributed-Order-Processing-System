# modules/ecs/outputs.tf

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "order_receiver_service_name" {
  description = "Name of the order receiver service"
  value       = aws_ecs_service.order_receiver.name
}

output "order_processor_service_name" {
  description = "Name of the order processor service"
  value       = aws_ecs_service.order_processor.name
}

output "order_receiver_task_definition_arn" {
  description = "ARN of the order receiver task definition"
  value       = aws_ecs_task_definition.order_receiver.arn
}

output "order_processor_task_definition_arn" {
  description = "ARN of the order processor task definition"
  value       = aws_ecs_task_definition.order_processor.arn
}
