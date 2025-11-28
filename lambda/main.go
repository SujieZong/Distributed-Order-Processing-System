package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// Order represents the order structure
type Order struct {
	OrderID     string  `json:"orderId"`
	ProductID   string  `json:"productId"`
	Quantity    int     `json:"quantity"`
	CustomerID  string  `json:"customerId"`
	TotalAmount float64 `json:"totalAmount"`
	Timestamp   string  `json:"timestamp"`
}

// ProcessingResult represents the result of order processing
type ProcessingResult struct {
	OrderID       string    `json:"orderId"`
	Status        string    `json:"status"`
	ProcessedAt   time.Time `json:"processedAt"`
	ProcessingTime float64  `json:"processingTime"`
	ColdStart     bool      `json:"coldStart"`
}

var (
	isColdStart = true
	startupTime = time.Now()
)

// HandleRequest processes SNS events containing orders
func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) error {
	coldStart := isColdStart
	isColdStart = false

	log.Printf("Lambda function invoked. Cold start: %v, Startup time: %v", coldStart, time.Since(startupTime))
	log.Printf("Processing %d SNS records", len(snsEvent.Records))

	for i, record := range snsEvent.Records {
		if err := processRecord(ctx, record, coldStart, i); err != nil {
			log.Printf("Error processing record %d: %v", i, err)
			// Continue processing other records even if one fails
			// In production, you might want to implement retry logic or DLQ
		}
	}

	return nil
}

// processRecord processes a single SNS record
func processRecord(ctx context.Context, record events.SNSEventRecord, coldStart bool, recordIndex int) error {
	startTime := time.Now()

	// Log SNS metadata
	log.Printf("Record %d - SNS Message ID: %s", recordIndex, record.SNS.MessageID)
	log.Printf("Record %d - SNS Subject: %s", recordIndex, record.SNS.Subject)
	log.Printf("Record %d - SNS Timestamp: %s", recordIndex, record.SNS.Timestamp)

	// Parse order from SNS message body
	var order Order
	if err := json.Unmarshal([]byte(record.SNS.Message), &order); err != nil {
		return fmt.Errorf("failed to unmarshal order: %w", err)
	}

	log.Printf("Record %d - Order received: OrderID=%s, ProductID=%s, Quantity=%d, CustomerID=%s, Amount=%.2f",
		recordIndex, order.OrderID, order.ProductID, order.Quantity, order.CustomerID, order.TotalAmount)

	// Simulate 3-second payment processing
	log.Printf("Record %d - Starting payment processing for order %s", recordIndex, order.OrderID)
	
	// Check for context timeout
	select {
	case <-time.After(3 * time.Second):
		// Payment processing completed
	case <-ctx.Done():
		return fmt.Errorf("processing canceled: %w", ctx.Err())
	}

	processingTime := time.Since(startTime).Seconds()

	// Log processing result
	result := ProcessingResult{
		OrderID:        order.OrderID,
		Status:         "COMPLETED",
		ProcessedAt:    time.Now(),
		ProcessingTime: processingTime,
		ColdStart:      coldStart,
	}

	resultJSON, _ := json.Marshal(result)
	log.Printf("Record %d - Payment processing completed: %s", recordIndex, string(resultJSON))

	// Additional metrics for CloudWatch
	log.Printf("Record %d - METRICS: OrderID=%s, ProcessingTime=%.3fs, ColdStart=%v, Amount=%.2f",
		recordIndex, order.OrderID, processingTime, coldStart, order.TotalAmount)

	return nil
}

func main() {
	// Set up structured logging
	log.SetPrefix("ORDER_PROCESSOR: ")
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds | log.LUTC)

	// Log Lambda environment info
	log.Printf("Lambda function initialized")
	log.Printf("AWS Region: %s", os.Getenv("AWS_REGION"))
	log.Printf("Function Name: %s", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
	log.Printf("Function Version: %s", os.Getenv("AWS_LAMBDA_FUNCTION_VERSION"))
	log.Printf("Memory Limit: %s MB", os.Getenv("AWS_LAMBDA_FUNCTION_MEMORY_SIZE"))

	// Start Lambda handler
	lambda.Start(HandleRequest)
}
