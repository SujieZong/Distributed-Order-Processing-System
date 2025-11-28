# Order Processing API

A synchronous order processing service built with Gin framework that simulates payment verification with realistic bottleneck using buffered channels.

## Features

- ✅ REST API with Gin framework
- ✅ `/health` endpoint for health checks
- ✅ `POST /orders/sync` for synchronous order processing
- ✅ Payment verification with 3-second delay using buffered channel pattern
- ✅ Proper error handling and logging
- ✅ Dockerized with Go 1.21-alpine
- ✅ Environment variable configuration

## Architecture

The service uses a **buffered channel pattern** to simulate a realistic payment processing bottleneck:

- **Payment Queue**: Buffered channel with configurable size (default: 100)
- **Payment Workers**: Multiple goroutines (default: 5) processing payments from the queue
- **3-Second Delay**: Each payment verification takes exactly 3 seconds
- **Throughput Control**: The buffered channel naturally limits throughput and creates backpressure

## API Endpoints

### Health Check

```bash
GET /health
Response: 200 OK
{
  "status": "OK"
}
```

### Process Order

```bash
POST /orders/sync
Content-Type: application/json

{
  "order_id": "ORD-123",
  "customer_id": 456,
  "status": "pending",
  "items": [
    {
      "product_id": "PROD-001",
      "quantity": 2,
      "price": 29.99
    }
  ],
  "created_at": "2025-10-25T10:30:00Z"
}

Response: 200 OK
{
  "order_id": "ORD-123",
  "customer_id": 456,
  "status": "completed",
  "items": [...],
  "created_at": "2025-10-25T10:30:00Z"
}
```

## Order Structure

```go
type Order struct {
    OrderID    string    `json:"order_id"`    // Required
    CustomerID int       `json:"customer_id"` // Required
    Status     string    `json:"status"`      // Required: pending, processing, completed
    Items      []Item    `json:"items"`       // Required: at least 1 item
    CreatedAt  time.Time `json:"created_at"`  // Required
}

type Item struct {
    ProductID string  `json:"product_id"` // Required
    Quantity  int     `json:"quantity"`   // Required: >= 1
    Price     float64 `json:"price"`      // Required: >= 0
}
```

## Environment Variables

| Variable             | Description                             | Default   |
| -------------------- | --------------------------------------- | --------- |
| `PORT`               | Server port                             | `8080`    |
| `PAYMENT_QUEUE_SIZE` | Buffered channel size for payment queue | `100`     |
| `PAYMENT_WORKERS`    | Number of payment processing workers    | `5`       |
| `GIN_MODE`           | Gin mode (debug/release)                | `release` |

## Running Locally

```bash
# Install dependencies
go mod download

# Run the service
go run main.go

# Or with custom configuration
PORT=3000 PAYMENT_WORKERS=10 go run main.go
```

## Building and Running with Docker

```bash
# Build the image
docker build -t order-api:latest .

# Run the container
docker run -p 8080:8080 order-api:latest

# Run with custom configuration
docker run -p 8080:8080 \
  -e PAYMENT_QUEUE_SIZE=200 \
  -e PAYMENT_WORKERS=10 \
  order-api:latest
```

## Testing

```bash
# Health check
curl http://localhost:8080/health

# Submit an order
curl -X POST http://localhost:8080/orders/sync \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-001",
    "customer_id": 123,
    "status": "pending",
    "items": [
      {
        "product_id": "PROD-001",
        "quantity": 1,
        "price": 99.99
      }
    ],
    "created_at": "2025-10-25T10:00:00Z"
  }'
```

## Payment Processing Flow

1. Order received at `/orders/sync`
2. Order validated (JSON schema, required fields)
3. Order status set to `processing`
4. Order queued to buffered payment channel
5. Worker picks up order from channel
6. Worker simulates payment verification (3-second delay)
7. Order status updated to `completed`
8. Response returned to client

## Error Handling

The API returns proper error responses:

- `400 Bad Request`: Invalid JSON or validation errors
- `503 Service Unavailable`: Payment queue is full

Example error response:

```json
{
  "error": "INVALID_REQUEST",
  "message": "Invalid order data: Key: 'Order.OrderID' Error:Field validation for 'OrderID' failed on the 'required' tag"
}
```

## Throughput Simulation

With default settings (5 workers, 3-second processing time):

- **Max throughput**: ~1.67 orders/second (5 workers / 3 seconds)
- **Queue capacity**: 100 orders buffered
- **Backpressure**: Automatic when queue is full

## Logging

The service logs all important events:

- Server startup configuration
- Payment processor initialization
- Order receipt and processing
- Payment completion
- Errors and validation failures

Example logs:

```
2025/10/25 10:30:00 Payment processor initialized with queue size: 100, workers: 5
2025/10/25 10:30:01 Starting Order Processing API server on port 8080
2025/10/25 10:30:05 Received order: ORD-001, customer: 123, items: 1
2025/10/25 10:30:05 Order ORD-001 queued for payment verification
2025/10/25 10:30:05 [Worker 1] Processing payment for order: ORD-001
2025/10/25 10:30:08 [Worker 1] Payment completed for order: ORD-001
2025/10/25 10:30:08 Order ORD-001 processed successfully
```
