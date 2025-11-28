#!/usr/bin/env python3
"""
Quick Demo Script for Locust Load Testing

This script demonstrates how to:
1. Generate realistic order payloads
2. View available test scenarios
3. Show example configurations
"""

import json
import random
from datetime import datetime, timezone


# Sample product catalog
PRODUCT_CATALOG = [
    {"product_id": "PROD-001", "name": "Wireless Headphones", "price_range": (29.99, 149.99)},
    {"product_id": "PROD-002", "name": "Laptop Stand", "price_range": (19.99, 79.99)},
    {"product_id": "PROD-003", "name": "USB-C Cable", "price_range": (9.99, 24.99)},
    {"product_id": "PROD-004", "name": "Mechanical Keyboard", "price_range": (49.99, 199.99)},
    {"product_id": "PROD-005", "name": "Wireless Mouse", "price_range": (19.99, 89.99)},
]


def generate_order_id():
    """Generate a unique order ID"""
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    random_suffix = random.randint(1000, 9999)
    return f"ORD-{timestamp}-{random_suffix}"


def generate_order_items():
    """Generate random order items"""
    num_items = random.randint(1, 3)
    items = []
    selected_products = random.sample(PRODUCT_CATALOG, num_items)
    
    for product in selected_products:
        quantity = random.randint(1, 3)
        price = round(random.uniform(*product["price_range"]), 2)
        items.append({
            "product_id": product["product_id"],
            "quantity": quantity,
            "price": price
        })
    
    return items


def generate_sample_order():
    """Generate a complete sample order"""
    return {
        "order_id": generate_order_id(),
        "customer_id": random.randint(100, 999),
        "status": "pending",
        "items": generate_order_items(),
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    }


def print_header(text):
    """Print a formatted header"""
    print("\n" + "=" * 80)
    print(f"  {text}")
    print("=" * 80)


def demo_order_generation():
    """Demonstrate order payload generation"""
    print_header("Sample Order Payloads")
    
    for i in range(3):
        order = generate_sample_order()
        print(f"\nOrder {i+1}:")
        print(json.dumps(order, indent=2))
        print(f"  Total items: {len(order['items'])}")
        total_value = sum(item['price'] * item['quantity'] for item in order['items'])
        print(f"  Total value: ${total_value:.2f}")


def show_test_scenarios():
    """Show available test scenarios"""
    print_header("Available Test Scenarios")
    
    scenarios = [
        {
            "name": "Normal Load",
            "command": "HEADLESS=true ./run_load_tests.sh normal",
            "users": 5,
            "spawn_rate": 1,
            "duration": "30s",
            "endpoint": "POST /orders/sync",
        },
        {
            "name": "Flash Sale",
            "command": "HEADLESS=true ./run_load_tests.sh flash-sale",
            "users": 20,
            "spawn_rate": 10,
            "duration": "60s",
            "endpoint": "POST /orders/async",
        },
        {
            "name": "Mixed Load",
            "command": "HEADLESS=true ./run_load_tests.sh mixed",
            "users": 15,
            "spawn_rate": 3,
            "duration": "60s",
            "endpoint": "Both sync and async",
        },
        {
            "name": "Stress Test",
            "command": "HEADLESS=true ./run_load_tests.sh stress",
            "users": 50,
            "spawn_rate": 20,
            "duration": "120s",
            "endpoint": "Both sync and async",
        },
    ]
    
    for scenario in scenarios:
        print(f"\n{scenario['name']}:")
        print(f"  Users: {scenario['users']} concurrent")
        print(f"  Spawn Rate: {scenario['spawn_rate']} users/sec")
        print(f"  Duration: {scenario['duration']}")
        print(f"  Endpoint: {scenario['endpoint']}")
        print(f"  Command: {scenario['command']}")


def show_quick_start():
    """Show quick start guide"""
    print_header("Quick Start Guide")
    
    print("""
1. Install Locust:
   pip install -r requirements.txt

2. Start your API:
   cd src && go run main.go

3. Run a test scenario:
   
   # Normal load test (recommended first test)
   HEADLESS=true ./run_load_tests.sh normal
   
   # Flash sale test
   HEADLESS=true ./run_load_tests.sh flash-sale
   
   # Web UI mode (for manual testing)
   ./run_load_tests.sh web
   
4. View results:
   Results are saved in: load_test_results/
   - HTML reports: *.html
   - CSV statistics: *_stats.csv
   - Failure logs: *_failures.csv

5. Check all available commands:
   ./run_load_tests.sh --help
""")


def show_curl_examples():
    """Show curl examples for manual testing"""
    print_header("Manual Testing with curl")
    
    order = generate_sample_order()
    
    print("\nTest sync endpoint:")
    print(f"""
curl -X POST http://localhost:8080/orders/sync \\
  -H "Content-Type: application/json" \\
  -d '{json.dumps(order)}'
""")
    
    print("\nTest async endpoint (if implemented):")
    print(f"""
curl -X POST http://localhost:8080/orders/async \\
  -H "Content-Type: application/json" \\
  -d '{json.dumps(order)}'
""")
    
    print("\nHealth check:")
    print("""
curl http://localhost:8080/health
""")


def main():
    """Main demo function"""
    print("\n" + "=" * 80)
    print("  LOCUST LOAD TESTING - DEMO & QUICK REFERENCE")
    print("=" * 80)
    
    # Show all sections
    demo_order_generation()
    show_test_scenarios()
    show_quick_start()
    show_curl_examples()
    
    print("\n" + "=" * 80)
    print("  For detailed documentation, see: LOAD_TESTING_README.md")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
