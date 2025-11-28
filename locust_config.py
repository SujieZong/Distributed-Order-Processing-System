"""
Locust Configuration for Different Test Scenarios

This file contains predefined configurations for different load testing scenarios.
Import these configurations when running Locust tests.
"""

# Normal Load Configuration
NORMAL_LOAD = {
    "users": 5,
    "spawn_rate": 1,  # users per second
    "run_time": "30s",
    "tags": ["sync"],
    "description": "Normal load: 5 concurrent users, 1 user/sec spawn rate, 30s duration"
}

# Flash Sale Configuration
FLASH_SALE = {
    "users": 20,
    "spawn_rate": 10,  # users per second
    "run_time": "60s",
    "tags": ["async"],
    "description": "Flash sale: 20 concurrent users, 10 users/sec spawn rate, 60s duration"
}

# Mixed Load Configuration
MIXED_LOAD = {
    "users": 15,
    "spawn_rate": 3,  # users per second
    "run_time": "60s",
    "tags": ["mixed"],
    "description": "Mixed load: 15 concurrent users, 3 users/sec spawn rate, 60s duration"
}

# Stress Test Configuration
STRESS_TEST = {
    "users": 50,
    "spawn_rate": 20,  # users per second
    "run_time": "120s",
    "tags": ["sync", "async"],
    "description": "Stress test: 50 concurrent users, 20 users/sec spawn rate, 120s duration"
}

# Endurance Test Configuration
ENDURANCE_TEST = {
    "users": 10,
    "spawn_rate": 2,  # users per second
    "run_time": "300s",  # 5 minutes
    "tags": ["mixed"],
    "description": "Endurance test: 10 concurrent users, 2 users/sec spawn rate, 5min duration"
}

# Spike Test Configuration
SPIKE_TEST = {
    "users": 100,
    "spawn_rate": 50,  # users per second
    "run_time": "30s",
    "tags": ["async"],
    "description": "Spike test: 100 concurrent users, 50 users/sec spawn rate, 30s duration"
}

# Test configurations dictionary
TEST_SCENARIOS = {
    "normal": NORMAL_LOAD,
    "flash_sale": FLASH_SALE,
    "mixed": MIXED_LOAD,
    "stress": STRESS_TEST,
    "endurance": ENDURANCE_TEST,
    "spike": SPIKE_TEST,
}


def get_scenario_config(scenario_name):
    """Get configuration for a specific scenario"""
    return TEST_SCENARIOS.get(scenario_name.lower(), NORMAL_LOAD)


def print_all_scenarios():
    """Print all available test scenarios"""
    print("\n" + "="*80)
    print("AVAILABLE LOAD TEST SCENARIOS")
    print("="*80)
    
    for name, config in TEST_SCENARIOS.items():
        print(f"\n{name.upper()}:")
        print(f"  Description: {config['description']}")
        print(f"  Users: {config['users']}")
        print(f"  Spawn Rate: {config['spawn_rate']} users/sec")
        print(f"  Duration: {config['run_time']}")
        print(f"  Tags: {', '.join(config['tags'])}")
    
    print("\n" + "="*80)


if __name__ == "__main__":
    print_all_scenarios()
