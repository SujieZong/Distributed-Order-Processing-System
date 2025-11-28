# modules/messaging/main.tf
# SNS and SQS configuration for order processing events

# SNS Topic for Order Processing Events
resource "aws_sns_topic" "order_processing_events" {
  name         = var.sns_topic_name
  display_name = "Order Processing Events"
  fifo_topic   = false
  
  tags = {
    Name = var.sns_topic_name
  }
}

# SQS Queue for Order Processing
resource "aws_sqs_queue" "order_processing" {
  name                       = var.sqs_queue_name
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = var.message_retention
  receive_wait_time_seconds  = var.receive_wait_time
  delay_seconds              = 0
  max_message_size           = 262144  # 256 KB
  
  tags = {
    Name = var.sqs_queue_name
  }
}

# Dead Letter Queue (optional but recommended for production)
resource "aws_sqs_queue" "order_processing_dlq" {
  name                      = "${var.sqs_queue_name}-dlq"
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 0

  tags = {
    Name = "${var.sqs_queue_name}-dlq"
    Type = "DLQ"
  }
}

# SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "order_processing" {
  queue_url = aws_sqs_queue.order_processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.order_processing.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_processing_events.arn
          }
        }
      }
    ]
  })
}

# SNS Subscription to SQS Queue
resource "aws_sns_topic_subscription" "order_processing_queue" {
  topic_arn = aws_sns_topic.order_processing_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.order_processing.arn
  
  # Raw message delivery (delivers the exact message without SNS wrapper)
  raw_message_delivery = true
}
