#!/bin/bash

# Test script for Order Processing API

BASE_URL="http://localhost:8080"

echo "======================================"
echo "Testing Order Processing API"
echo "======================================"
echo

# Test 1: Health Check
echo "1. Testing Health Check Endpoint..."
echo "GET $BASE_URL/health"
curl -s $BASE_URL/health | jq .
echo
echo

# Test 2: Valid Order
echo "2. Testing Valid Order Submission..."
echo "POST $BASE_URL/orders/sync"
curl -s -X POST $BASE_URL/orders/sync \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-001",
    "customer_id": 123,
    "status": "pending",
    "items": [
      {
        "product_id": "PROD-001",
        "quantity": 2,
        "price": 29.99
      },
      {
        "product_id": "PROD-002",
        "quantity": 1,
        "price": 49.99
      }
    ],
    "created_at": "2025-10-25T10:00:00Z"
  }' | jq .
echo
echo

# Test 3: Missing Required Field
echo "3. Testing Missing Required Field (order_id)..."
echo "POST $BASE_URL/orders/sync"
curl -s -X POST $BASE_URL/orders/sync \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 123,
    "status": "pending",
    "items": [
      {
        "product_id": "PROD-001",
        "quantity": 1,
        "price": 29.99
      }
    ],
    "created_at": "2025-10-25T10:00:00Z"
  }' | jq .
echo
echo

# Test 4: Invalid Status Value
echo "4. Testing Invalid Status Value..."
echo "POST $BASE_URL/orders/sync"
curl -s -X POST $BASE_URL/orders/sync \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-003",
    "customer_id": 123,
    "status": "invalid_status",
    "items": [
      {
        "product_id": "PROD-001",
        "quantity": 1,
        "price": 29.99
      }
    ],
    "created_at": "2025-10-25T10:00:00Z"
  }' | jq .
echo
echo

# Test 5: Empty Items Array
echo "5. Testing Empty Items Array..."
echo "POST $BASE_URL/orders/sync"
curl -s -X POST $BASE_URL/orders/sync \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-004",
    "customer_id": 123,
    "status": "pending",
    "items": [],
    "created_at": "2025-10-25T10:00:00Z"
  }' | jq .
echo
echo

# Test 6: Invalid Item Quantity
echo "6. Testing Invalid Item Quantity (0)..."
echo "POST $BASE_URL/orders/sync"
curl -s -X POST $BASE_URL/orders/sync \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-005",
    "customer_id": 123,
    "status": "pending",
    "items": [
      {
        "product_id": "PROD-001",
        "quantity": 0,
        "price": 29.99
      }
    ],
    "created_at": "2025-10-25T10:00:00Z"
  }' | jq .
echo
echo

# Test 7: Multiple Concurrent Orders
echo "7. Testing Multiple Concurrent Orders (5 orders)..."
echo "This will take ~3 seconds due to payment processing delay"
for i in {1..5}; do
  (
    curl -s -X POST $BASE_URL/orders/sync \
      -H "Content-Type: application/json" \
      -d "{
        \"order_id\": \"ORD-CONCURRENT-$i\",
        \"customer_id\": $((100 + i)),
        \"status\": \"pending\",
        \"items\": [
          {
            \"product_id\": \"PROD-001\",
            \"quantity\": 1,
            \"price\": 29.99
          }
        ],
        \"created_at\": \"2025-10-25T10:00:00Z\"
      }" > /dev/null &
  )
done

# Wait for all background jobs
wait

echo "All concurrent orders submitted"
echo
echo "======================================"
echo "Testing Complete!"
echo "======================================"
