package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sns"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/gin-gonic/gin"
)

// Item represents an item in an order
type Item struct {
    ProductID string  `json:"product_id" binding:"required"`
    Quantity  int     `json:"quantity" binding:"required,gt=0"`  // Changed from just "required"
    Price     float64 `json:"price" binding:"required,gt=0"`
}

// Order represents an order in the system
type Order struct {
    OrderID    string    `json:"order_id" binding:"required"`
    CustomerID int       `json:"customer_id" binding:"required,gt=0"`
    Status     string    `json:"status" binding:"required,oneof=pending processing completed"`
    Items      []Item    `json:"items" binding:"required,min=1,dive"`
    CreatedAt  time.Time `json:"created_at" binding:"required"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// PaymentProcessor manages payment verification with buffered channel
// The buffered channel acts as a semaphore to limit concurrent payment processing
// This simulates a real payment gateway bottleneck
type PaymentProcessor struct {
	paymentSemaphore chan struct{}
}

// NewPaymentProcessor creates a new payment processor with buffered channel
// The channel size determines how many concurrent payments can be processed
func NewPaymentProcessor(concurrentLimit int) *PaymentProcessor {
	pp := &PaymentProcessor{}

	if concurrentLimit > 0 {
		pp.paymentSemaphore = make(chan struct{}, concurrentLimit)
	}

	log.Printf("Payment processor initialized with concurrent limit: %d", concurrentLimit)
	return pp
}

// VerifyPayment processes payment with simulated 3-second delay
// PAYMENT GATEWAY LIMIT REMOVED FOR EXPERIMENT 2
// No concurrency limit - allows unlimited parallel payment processing
func (pp *PaymentProcessor) VerifyPayment(order *Order) error {
	// Update status to processing
	order.Status = "processing"
	log.Printf("Processing payment for order: %s", order.OrderID)
	
	// Simulate payment verification with 3-second delay
	// This blocks the goroutine but other goroutines can still run
	time.Sleep(3 * time.Second)
	
	// Update status to completed
	order.Status = "completed"
	log.Printf("Payment completed for order: %s", order.OrderID)
	
	return nil
}

// Global payment processor (uses buffered channel to limit concurrent payments)
var paymentProcessor *PaymentProcessor

// AWS clients
var (
	snsClient *sns.SNS
	sqsClient *sqs.SQS
	snsTopicARN string
	sqsQueueURL string
)

// healthCheckHandler handles GET /health
func healthCheckHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "OK",
	})
}

// syncOrderHandler handles POST /orders/sync
func syncOrderHandler(c *gin.Context) {
	var order Order
	
	// Bind and validate JSON request
	if err := c.ShouldBindJSON(&order); err != nil {
		log.Printf("Invalid request body: %v", err)
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error:   "INVALID_REQUEST",
			Message: fmt.Sprintf("Invalid order data: %v", err),
		})
		return
	}
	
	log.Printf("Received order: %s, customer: %d, items: %d", 
		order.OrderID, order.CustomerID, len(order.Items))
	
	// ASYNCHRONOUS PROCESSING with buffered channel to limit concurrency
	// EXPERIMENT 2: Payment gateway limit removed - no bottleneck
	if err := paymentProcessor.VerifyPayment(&order); err != nil {
		log.Printf("Payment verification failed: %v", err)
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{
			Error:   "SERVICE_UNAVAILABLE",
			Message: err.Error(),
		})
		return
	}
	
	// Return processed order
	c.JSON(http.StatusOK, order)
	log.Printf("Order %s processed successfully", order.OrderID)
}

// asyncOrderHandler handles POST /orders/async
func asyncOrderHandler(c *gin.Context) {
	var order Order
	
	// Bind and validate JSON request
	if err := c.ShouldBindJSON(&order); err != nil {
		log.Printf("Invalid request body: %v", err)
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error:   "INVALID_REQUEST",
			Message: fmt.Sprintf("Invalid order data: %v", err),
		})
		return
	}
	
	log.Printf("Received async order: %s, customer: %d, items: %d", 
		order.OrderID, order.CustomerID, len(order.Items))
	
	// Check if SNS client is initialized
	if snsClient == nil {
		log.Printf("SNS client not initialized")
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{
			Error:   "SERVICE_UNAVAILABLE",
			Message: "Async order processing is not available",
		})
		return
	}
	
	// ASYNCHRONOUS PROCESSING - Publish to SNS
	// Marshal order to JSON
	orderJSON, err := json.Marshal(order)
	if err != nil {
		log.Printf("Failed to marshal order: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to process order",
		})
		return
	}
	
	// Publish to SNS topic
	_, err = snsClient.Publish(&sns.PublishInput{
		TopicArn: aws.String(snsTopicARN),
		Message:  aws.String(string(orderJSON)),
		MessageAttributes: map[string]*sns.MessageAttributeValue{
			"order_id": {
				DataType:    aws.String("String"),
				StringValue: aws.String(order.OrderID),
			},
		},
	})
	
	if err != nil {
		log.Printf("Failed to publish to SNS: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to queue order for processing",
		})
		return
	}
	
	// Return 202 Accepted immediately
	c.JSON(http.StatusAccepted, gin.H{
		"order_id": order.OrderID,
		"status":   "accepted",
		"message":  "Order accepted and queued for processing",
	})
	log.Printf("Order %s queued for async processing", order.OrderID)
}

// setupRouter configures and returns the Gin router
func setupRouter() *gin.Engine {
	// Set Gin to release mode if in production
	if os.Getenv("GIN_MODE") == "" {
		gin.SetMode(gin.ReleaseMode)
	}
	
	router := gin.Default()
	
	// Configure CORS middleware
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusOK)
			return
		}
		
		c.Next()
	})
	
	// Register routes
	router.GET("/health", healthCheckHandler)
	router.POST("/orders/sync", syncOrderHandler)
	router.POST("/orders/async", asyncOrderHandler)
	
	return router
}

// orderProcessor continuously polls SQS and processes orders
// OPTIMIZED: Multiple concurrent pollers + batch deletion
func orderProcessor(ctx context.Context, numWorkers int) {
	log.Printf("Starting order processor with %d workers", numWorkers)
	
	// Worker semaphore to limit concurrent processing
	workerSemaphore := make(chan struct{}, numWorkers)
	
	// Channel for batching deletes - OPTIMIZATION: Batch Deletion
	deleteQueue := make(chan *sqs.Message, 100)
	
	// Metrics tracking with atomic operations
	var processedCount int64
	startTime := time.Now()
	var lastProcessedCount int64
	lastLogTime := time.Now()
	
	// OPTIMIZATION: Batch Delete Goroutine
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()
		batch := make([]*sqs.Message, 0, 10)
		
		for {
			select {
			case <-ctx.Done():
				// Flush remaining deletes on shutdown
				if len(batch) > 0 {
					batchDeleteMessages(batch)
				}
				return
			case msg := <-deleteQueue:
				batch = append(batch, msg)
				// Batch when we hit 10 messages (SQS limit)
				if len(batch) >= 10 {
					batchDeleteMessages(batch)
					batch = make([]*sqs.Message, 0, 10)
				}
			case <-ticker.C:
				// Flush partial batch every second
				if len(batch) > 0 {
					batchDeleteMessages(batch)
					batch = make([]*sqs.Message, 0, 10)
				}
			}
		}
	}()
	
	// Start metrics logging goroutine
	go func() {
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				// Calculate processing rate
				elapsed := time.Since(lastLogTime).Seconds()
				processed := atomic.LoadInt64(&processedCount) - lastProcessedCount
				rate := float64(processed) / elapsed
				
				// Get queue depth
				queueDepth := getQueueDepth()
				
				// Log metrics
				totalElapsed := time.Since(startTime).Seconds()
				avgRate := float64(atomic.LoadInt64(&processedCount)) / totalElapsed
				log.Printf("METRICS: Processed=%d | Rate=%.2f orders/sec (last 10s) | Avg Rate=%.2f orders/sec | Queue Depth=%d | Active Workers=%d/%d",
					atomic.LoadInt64(&processedCount), rate, avgRate, queueDepth, len(workerSemaphore), numWorkers)
				
				lastLogTime = time.Now()
				lastProcessedCount = atomic.LoadInt64(&processedCount)
			}
		}
	}()
	
	// OPTIMIZATION: Calculate optimal number of concurrent SQS pollers
	// Rule: 1 poller per 15 workers, minimum 2, maximum 10
	numPollers := (numWorkers / 15) + 1
	if numPollers < 2 {
		numPollers = 2
	}
	if numPollers > 10 {
		numPollers = 10
	}
	
	log.Printf("Starting %d concurrent SQS pollers for %d workers", numPollers, numWorkers)
	
	// OPTIMIZATION: Multiple concurrent SQS pollers
	for i := 0; i < numPollers; i++ {
		go func(pollerID int) {
			log.Printf("Poller %d started", pollerID)
			
			for {
				select {
				case <-ctx.Done():
					log.Printf("Poller %d shutting down...", pollerID)
					return
				default:
					// Receive messages from SQS
					result, err := sqsClient.ReceiveMessage(&sqs.ReceiveMessageInput{
						QueueUrl:            aws.String(sqsQueueURL),
						MaxNumberOfMessages: aws.Int64(10),
						WaitTimeSeconds:     aws.Int64(20), // Keep original setting
						VisibilityTimeout:   aws.Int64(30),
					})
					
					if err != nil {
						log.Printf("Poller %d: Error receiving messages: %v", pollerID, err)
						time.Sleep(5 * time.Second)
						continue
					}
					
					if len(result.Messages) == 0 {
						continue
					}
					
					log.Printf("Poller %d: Received %d messages", pollerID, len(result.Messages))
					
					// Process each message in a separate goroutine
					for _, message := range result.Messages {
						// Acquire semaphore slot (blocks if at capacity)
						workerSemaphore <- struct{}{}
						
						go func(msg *sqs.Message) {
							defer func() {
								<-workerSemaphore // Release slot when done
								atomic.AddInt64(&processedCount, 1)
							}()
							
							processMessageWithDelete(msg, deleteQueue)
						}(message)
					}
				}
			}
		}(i)
	}
	
	// Wait for shutdown
	<-ctx.Done()
	log.Println("Order processor shutting down...")
	
	// Wait a bit for in-flight messages
	time.Sleep(3 * time.Second)
}

// getQueueDepth retrieves the approximate number of messages in the queue
func getQueueDepth() int {
	result, err := sqsClient.GetQueueAttributes(&sqs.GetQueueAttributesInput{
		QueueUrl: aws.String(sqsQueueURL),
		AttributeNames: []*string{
			aws.String("ApproximateNumberOfMessages"),
			aws.String("ApproximateNumberOfMessagesNotVisible"),
		},
	})
	
	if err != nil {
		log.Printf("Failed to get queue attributes: %v", err)
		return -1
	}
	
	visible := 0
	notVisible := 0
	
	if val, ok := result.Attributes["ApproximateNumberOfMessages"]; ok {
		fmt.Sscanf(*val, "%d", &visible)
	}
	if val, ok := result.Attributes["ApproximateNumberOfMessagesNotVisible"]; ok {
		fmt.Sscanf(*val, "%d", &notVisible)
	}
	
	return visible + notVisible
}

// SNSMessage represents the SNS message wrapper
type SNSMessage struct {
	Type      string `json:"Type"`
	MessageId string `json:"MessageId"`
	TopicArn  string `json:"TopicArn"`
	Message   string `json:"Message"` // This is the actual order JSON as string
	Timestamp string `json:"Timestamp"`
}

// processMessageWithDelete processes a single SQS message and queues it for deletion
func processMessageWithDelete(message *sqs.Message, deleteQueue chan<- *sqs.Message) bool {
	log.Printf("Processing message: %s", *message.MessageId)
	
	var order Order
	messageBody := *message.Body
	
	// Check if message is wrapped in SNS envelope
	// SNS messages start with {"Type":"Notification"...}
	if messageBody[0] == '{' && (len(messageBody) > 20 && messageBody[1:7] == `"Type"`) {
		// Try to parse as SNS message
		var snsMessage SNSMessage
		if err := json.Unmarshal([]byte(messageBody), &snsMessage); err == nil && snsMessage.Type == "Notification" {
			// Extract the actual order JSON from SNS Message field
			messageBody = snsMessage.Message
			log.Printf("Unwrapped SNS message envelope")
		}
	}
	
	// Parse order from message body (either raw or unwrapped from SNS)
	if err := json.Unmarshal([]byte(messageBody), &order); err != nil {
		log.Printf("Failed to unmarshal order from message: %v", err)
		log.Printf("Message body: %s", messageBody)
		// Delete malformed message to avoid reprocessing
		deleteQueue <- message
		return false
	}
	
	log.Printf("Processing order from queue: %s", order.OrderID)
	
	// Process payment (this will block for 3 seconds)
	if err := paymentProcessor.VerifyPayment(&order); err != nil {
		log.Printf("Payment processing failed for order %s: %v", order.OrderID, err)
		// Message will become visible again after visibility timeout
		return false
	}
	
	log.Printf("Order %s processed successfully from queue", order.OrderID)
	
	// Queue for batch deletion
	deleteQueue <- message
	return true
}

// batchDeleteMessages deletes multiple messages in a single API call
// OPTIMIZATION: 10x reduction in API calls
func batchDeleteMessages(messages []*sqs.Message) {
	if len(messages) == 0 {
		return
	}
	
	entries := make([]*sqs.DeleteMessageBatchRequestEntry, len(messages))
	for i, msg := range messages {
		entries[i] = &sqs.DeleteMessageBatchRequestEntry{
			Id:            aws.String(fmt.Sprintf("msg-%d", i)),
			ReceiptHandle: msg.ReceiptHandle,
		}
	}
	
	result, err := sqsClient.DeleteMessageBatch(&sqs.DeleteMessageBatchInput{
		QueueUrl: aws.String(sqsQueueURL),
		Entries:  entries,
	})
	
	if err != nil {
		log.Printf("Batch delete failed: %v", err)
		return
	}
	
	if len(result.Failed) > 0 {
		log.Printf("Batch delete: %d succeeded, %d failed", len(result.Successful), len(result.Failed))
		for _, failed := range result.Failed {
			log.Printf("Failed to delete message %s: %s", *failed.Id, *failed.Message)
		}
	} else {
		log.Printf("Batch deleted %d messages", len(result.Successful))
	}
}

func main() {
	// Load configuration from environment variables
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	
	// Service mode: "receiver" or "processor"
	serviceMode := os.Getenv("SERVICE_MODE")
	if serviceMode == "" {
		serviceMode = "receiver" // Default to receiver
	}
	
	// AWS configuration
	awsRegion := os.Getenv("AWS_REGION")
	if awsRegion == "" {
		awsRegion = "us-west-2"
	}
	snsTopicARN = os.Getenv("SNS_TOPIC_ARN")
	sqsQueueURL = os.Getenv("SQS_QUEUE_URL")
	
	// Number of worker goroutines for processor mode
	// EXPERIMENT 2: Start with 1 worker, scale up to test concurrency
	// Payment gateway limit removed - no artificial bottleneck
	numWorkers := 1
	if workersEnv := os.Getenv("NUM_WORKERS"); workersEnv != "" {
		fmt.Sscanf(workersEnv, "%d", &numWorkers)
	}
	
	// Initialize payment processor (no limit for Experiment 2)
	paymentProcessor = NewPaymentProcessor(0) // 0 = unlimited
	
	// Initialize AWS clients if SNS/SQS are configured
	if snsTopicARN != "" || sqsQueueURL != "" {
		sess, err := session.NewSession(&aws.Config{
			Region: aws.String(awsRegion),
		})
		if err != nil {
			// Don't crash the receiver - just log the error
			// The receiver can still handle sync requests even without AWS
			log.Printf("WARNING: Failed to create AWS session: %v", err)
			log.Printf("Async order processing will not be available")
		} else {
			snsClient = sns.New(sess)
			sqsClient = sqs.New(sess)
			log.Printf("AWS clients initialized (Region: %s)", awsRegion)
			if snsTopicARN != "" {
				log.Printf("  SNS Topic: %s", snsTopicARN)
			}
			if sqsQueueURL != "" {
				log.Printf("  SQS Queue: %s", sqsQueueURL)
			}
		}
	}
	
	// Context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	if serviceMode == "processor" {
		// PROCESSOR MODE: Poll SQS and process orders
		log.Printf("Starting in PROCESSOR mode")
		log.Printf("Configuration:")
		log.Printf("  Processing Mode: ASYNCHRONOUS (SQS polling)")
		log.Printf("  Number of Workers: %d goroutines", numWorkers)
		numPollers := (numWorkers / 15) + 1
		if numPollers < 2 {
			numPollers = 2
		}
		if numPollers > 10 {
			numPollers = 10
		}
		log.Printf("  Number of SQS Pollers: %d (auto-calculated)", numPollers)
		log.Printf("  Payment Processing Limit: UNLIMITED (Experiment 2 - No bottleneck)")
		log.Printf("  Payment Delay: 3 seconds per payment")
		log.Printf("  SQS Long Polling: 20 seconds")
		log.Printf("  Max Messages per Poll: 10")
		log.Printf("  Batch Deletion: Enabled (10 messages per API call)")
		log.Printf("  Visibility Timeout: 30 seconds")
		log.Printf("  Task Resources: CPU 256 units, Memory 512MB")
		
		if sqsQueueURL == "" {
			log.Fatal("SQS_QUEUE_URL must be set for processor mode")
		}
		
		// Start order processor
		go orderProcessor(ctx, numWorkers)
		
		// Wait for interrupt signal
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		
		log.Println("Shutting down processor...")
		cancel()
		
		// Give some time for in-flight messages to complete
		time.Sleep(5 * time.Second)
		log.Println("Processor exited")
		
	} else {
		// RECEIVER MODE: HTTP API server
		log.Printf("Starting in RECEIVER mode")
		
		// Setup router
		router := setupRouter()
		
		// Create HTTP server
		srv := &http.Server{
			Addr:    ":" + port,
			Handler: router,
		}
		
		// Start server in goroutine
		go func() {
			log.Printf("Starting Order Processing API server on port %s", port)
			log.Printf("Configuration:")
			log.Printf("  Processing Mode: HYBRID (sync + async)")
			log.Printf("  Payment Processing Limit: UNLIMITED (Experiment 2)")
			log.Printf("  Payment Delay: 3 seconds per payment")
			log.Printf("Endpoints:")
			log.Printf("  GET  /health")
			log.Printf("  POST /orders/sync  - Synchronous order processing")
			log.Printf("  POST /orders/async - Asynchronous order processing (via SNS/SQS)")
			
			if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
				log.Printf("FATAL: Server failed to start: %v", err)
				os.Exit(1)
			}
		}()
		
		// Wait for interrupt signal to gracefully shutdown the server
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		
		log.Println("Shutting down server...")
		
		// Graceful shutdown with 5 second timeout
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer shutdownCancel()
		
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Fatal("Server forced to shutdown:", err)
		}
		
		log.Println("Server exited")
	}
}