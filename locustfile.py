"""
Locust Load Testing Script for E-commerce Order Processing API

This script tests the order processing endpoints with two scenarios:
1. Normal load: 5 concurrent users, spawn rate 1 user/second
2. Flash sale: 20 concurrent users, spawn rate 10 users/second

Usage:
  Normal load (30s duration):
    locust -f locustfile.py --host=http://localhost:8080 \
           --users=5 --spawn-rate=1 --run-time=30s --tags sync

  Flash sale (60s duration):
    locust -f locustfile.py --host=http://localhost:8080 \
           --users=20 --spawn-rate=10 --run-time=60s --tags async

  Both scenarios:
    locust -f locustfile.py --host=http://localhost:8080 \
           --users=20 --spawn-rate=5 --run-time=90s

  Web UI mode:
    locust -f locustfile.py --host=http://localhost:8080
"""

import random
import json
from datetime import datetime, timezone
from locust import HttpUser, TaskSet, task, tag, between, events
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# Sample product catalog for realistic order generation
PRODUCT_CATALOG = [
    {"product_id": "PROD-001", "name": "Wireless Headphones", "price_range": (29.99, 149.99)},
    {"product_id": "PROD-002", "name": "Laptop Stand", "price_range": (19.99, 79.99)},
    {"product_id": "PROD-003", "name": "USB-C Cable", "price_range": (9.99, 24.99)},
    {"product_id": "PROD-004", "name": "Mechanical Keyboard", "price_range": (49.99, 199.99)},
    {"product_id": "PROD-005", "name": "Wireless Mouse", "price_range": (19.99, 89.99)},
    {"product_id": "PROD-006", "name": "Monitor", "price_range": (149.99, 599.99)},
    {"product_id": "PROD-007", "name": "Webcam", "price_range": (39.99, 149.99)},
    {"product_id": "PROD-008", "name": "Phone Case", "price_range": (9.99, 39.99)},
    {"product_id": "PROD-009", "name": "Power Bank", "price_range": (19.99, 79.99)},
    {"product_id": "PROD-010", "name": "Desk Lamp", "price_range": (24.99, 89.99)},
]

# Customer ID pool for realistic distribution
CUSTOMER_ID_POOL = list(range(100, 1000))


def generate_order_id():
    """Generate a unique order ID with timestamp"""
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    random_suffix = random.randint(1000, 9999)
    return f"ORD-{timestamp}-{random_suffix}"


def generate_order_items():
    """Generate realistic order items with random products and quantities"""
    num_items = random.randint(1, 5)  # 1-5 items per order
    items = []
    
    # Select random products without replacement
    selected_products = random.sample(PRODUCT_CATALOG, num_items)
    
    for product in selected_products:
        quantity = random.randint(1, 3)  # 1-3 quantity per item
        price = round(random.uniform(*product["price_range"]), 2)
        
        items.append({
            "product_id": product["product_id"],
            "quantity": quantity,
            "price": price
        })
    
    return items


def generate_order_payload():
    """Generate a realistic order payload"""
    return {
        "order_id": generate_order_id(),
        "customer_id": random.choice(CUSTOMER_ID_POOL),  # Already an integer
        "status": "pending",
        "items": generate_order_items(),
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    }


class SyncOrderTaskSet(TaskSet):
    """Task set for testing synchronous order processing"""
    
    @task(10)
    @tag('sync')
    def create_sync_order(self):
        """Test POST /orders/sync endpoint"""
        order_payload = generate_order_payload()
        
        with self.client.post(
            "/orders/sync",
            json=order_payload,
            catch_response=True,
            name="POST /orders/sync"
        ) as response:
            if response.status_code == 200:
                try:
                    response_data = response.json()
                    logger.debug(f"Sync order created: {response_data.get('order_id')}")
                    response.success()
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            elif response.status_code == 503:
                # Service unavailable - queue full
                logger.warning("Payment queue is full (503)")
                response.failure("Service unavailable - payment queue full")
            else:
                response.failure(f"Unexpected status code: {response.status_code}")
    
    @task(1)
    @tag('health')
    def health_check(self):
        """Test GET /health endpoint"""
        with self.client.get(
            "/health",
            catch_response=True,
            name="GET /health"
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")


class AsyncOrderTaskSet(TaskSet):
    """Task set for testing asynchronous order processing"""
    
    @task(10)
    @tag('async')
    def create_async_order(self):
        """Test POST /orders/async endpoint"""
        order_payload = generate_order_payload()
        
        with self.client.post(
            "/orders/async",
            json=order_payload,
            catch_response=True,
            name="POST /orders/async"
        ) as response:
            if response.status_code == 202:
                try:
                    response_data = response.json()
                    logger.debug(f"Async order accepted: {response_data.get('order_id')}")
                    response.success()
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            elif response.status_code == 500:
                logger.warning("Failed to queue order (500)")
                response.failure("Internal server error")
            else:
                response.failure(f"Unexpected status code: {response.status_code}")
    
    @task(1)
    @tag('health')
    def health_check(self):
        """Test GET /health endpoint"""
        with self.client.get(
            "/health",
            catch_response=True,
            name="GET /health"
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")


class MixedOrderTaskSet(TaskSet):
    """Task set for testing both sync and async endpoints"""
    
    @task(5)
    @tag('sync', 'mixed')
    def create_sync_order(self):
        """Test POST /orders/sync endpoint"""
        order_payload = generate_order_payload()
        
        with self.client.post(
            "/orders/sync",
            json=order_payload,
            catch_response=True,
            name="POST /orders/sync"
        ) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 503:
                response.failure("Service unavailable - payment queue full")
            else:
                response.failure(f"Unexpected status code: {response.status_code}")
    
    @task(5)
    @tag('async', 'mixed')
    def create_async_order(self):
        """Test POST /orders/async endpoint"""
        order_payload = generate_order_payload()
        
        with self.client.post(
            "/orders/async",
            json=order_payload,
            catch_response=True,
            name="POST /orders/async"
        ) as response:
            if response.status_code == 202:
                response.success()
            elif response.status_code == 500:
                response.failure("Failed to queue order")
            else:
                response.failure(f"Unexpected status code: {response.status_code}")


class NormalLoadUser(HttpUser):
    """
    Normal load scenario: 5 concurrent users, spawn rate 1 user/second
    Run for 30 seconds
    
    Usage:
        locust -f locustfile.py --host=http://localhost:8080 \
               --users=5 --spawn-rate=1 --run-time=30s \
               --tags sync NormalLoadUser
    """
    tasks = [SyncOrderTaskSet]
    wait_time = between(0.1, 0.5)  # 100-500ms wait time between requests
    
    def on_start(self):
        """Called when a user starts"""
        logger.info(f"Normal load user started: {self.environment.runner.user_count} total users")


class FlashSaleUser(HttpUser):
    """
    Flash sale scenario: 20 concurrent users, spawn rate 10 users/second
    Run for 60 seconds
    Tests /orders/async for high throughput
    
    Usage:
        locust -f locustfile.py --host=http://localhost:8080 \
               --users=20 --spawn-rate=10 --run-time=60s \
               --tags async FlashSaleUser
    """
    tasks = [AsyncOrderTaskSet]  # Use async for flash sales
    wait_time = between(0.1, 0.5)  # 100-500ms wait time between requests
    
    def on_start(self):
        """Called when a user starts"""
        logger.info(f"Flash sale user started: {self.environment.runner.user_count} total users")


class MixedLoadUser(HttpUser):
    """
    Mixed load scenario: Tests both sync and async endpoints
    
    Usage:
        locust -f locustfile.py --host=http://localhost:8080 \
               --users=10 --spawn-rate=2 --run-time=60s MixedLoadUser
    """
    tasks = [MixedOrderTaskSet]
    wait_time = between(0.1, 0.5)  # 100-500ms wait time between requests


# Event hooks for custom metrics and logging
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the test starts"""
    logger.info("="*80)
    logger.info("Load test started")
    logger.info(f"Target host: {environment.host}")
    logger.info("="*80)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the test stops"""
    logger.info("="*80)
    logger.info("Load test completed")
    logger.info("="*80)
    
    # Print summary statistics
    stats = environment.stats
    logger.info("\n" + "="*80)
    logger.info("LOAD TEST SUMMARY")
    logger.info("="*80)
    
    for name, stat in stats.entries.items():
        if stat.num_requests > 0:
            logger.info(f"\nEndpoint: {name}")
            logger.info(f"  Total requests: {stat.num_requests}")
            logger.info(f"  Failures: {stat.num_failures}")
            logger.info(f"  Success rate: {((stat.num_requests - stat.num_failures) / stat.num_requests * 100):.2f}%")
            logger.info(f"  Average response time: {stat.avg_response_time:.2f}ms")
            logger.info(f"  Min response time: {stat.min_response_time:.2f}ms")
            logger.info(f"  Max response time: {stat.max_response_time:.2f}ms")
            logger.info(f"  Median response time: {stat.median_response_time:.2f}ms")
            logger.info(f"  95th percentile: {stat.get_response_time_percentile(0.95):.2f}ms")
            logger.info(f"  99th percentile: {stat.get_response_time_percentile(0.99):.2f}ms")
            logger.info(f"  Requests per second: {stat.total_rps:.2f}")
    
    logger.info("\n" + "="*80)
    logger.info(f"Total requests: {stats.total.num_requests}")
    logger.info(f"Total failures: {stats.total.num_failures}")
    logger.info(f"Overall success rate: {((stats.total.num_requests - stats.total.num_failures) / stats.total.num_requests * 100):.2f}%" if stats.total.num_requests > 0 else "N/A")
    logger.info(f"Average RPS: {stats.total.total_rps:.2f}")
    logger.info("="*80)


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, context, **kwargs):
    """Called after each request - can be used for custom metrics"""
    if exception:
        logger.debug(f"Request failed: {name} - {exception}")
