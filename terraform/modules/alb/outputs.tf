# modules/alb/outputs.tf

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "order_receiver_target_group_arn" {
  description = "ARN of the order receiver target group"
  value       = aws_lb_target_group.order_receiver.arn
}

output "order_processor_target_group_arn" {
  description = "ARN of the order processor target group"
  value       = aws_lb_target_group.order_processor.arn
}

output "listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}
