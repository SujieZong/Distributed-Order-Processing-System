#!/bin/bash

# Load Testing Script for Order Processing Service on AWS
# Runs both Normal Operations and Flash Sale tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALB_DNS_FILE="$PROJECT_ROOT/.alb_dns"
OUTPUT_DIR="reports"
AWS_REGION="us-west-2"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Locust is installed
check_locust() {
    if ! command -v locust &> /dev/null; then
        print_error "Locust is not installed!"
        print_info "Install it with: pip install locust"
        exit 1
    fi
    print_success "Locust is installed ($(locust --version))"
}

# Function to get ALB DNS
get_alb_dns() {
    if [ -f "$ALB_DNS_FILE" ]; then
        HOST=$(cat "$ALB_DNS_FILE")
        HOST="http://$HOST"
        print_success "Using ALB DNS from .alb_dns file"
    else
        # Try to get from Terraform output
        cd "$PROJECT_ROOT/terraform"
        if [ -f "terraform.tfstate" ]; then
            ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
            if [ -z "$ALB_DNS" ]; then
                print_error "Could not determine ALB DNS"
                print_info "Please run ./deploy.sh first or set API_HOST manually"
                exit 1
            fi
            HOST="http://$ALB_DNS"
        else
            print_error "Infrastructure not deployed"
            print_info "Please run ./deploy.sh first"
            exit 1
        fi
        cd "$PROJECT_ROOT"
    fi
    print_info "Target Host: ${HOST}"
}

# Function to check if API is running
check_api() {
    print_info "Checking if API is running..."
    if curl -s "${HOST}/health" > /dev/null 2>&1; then
        print_success "API is running and healthy"
    else
        print_warning "API health check failed. The service may still be starting up."
        print_info "Wait a minute and try again, or check ECS service status"
    fi
}

# Function to create output directory
setup_output_dir() {
    mkdir -p "${OUTPUT_DIR}"
    print_info "Results will be saved to: ${OUTPUT_DIR}"
}

# Function to run a load test
run_test() {
    local scenario=$1
    local users=$2
    local spawn_rate=$3
    local run_time=$4
    local user_class=$5
    local endpoint=$6
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    print_info "=========================================="
    print_info "Running ${scenario} load test"
    print_info "=========================================="
    print_info "Configuration:"
    print_info "  Host: ${HOST}"
    print_info "  Users: ${users}"
    print_info "  Spawn Rate: ${spawn_rate} users/sec"
    print_info "  Duration: ${run_time}"
    print_info "  User Class: ${user_class}"
    print_info "  Endpoint: ${endpoint}"
    print_info "  Wait Time: 100-500ms (random)"
    print_info "  Timestamp: ${timestamp}"
    print_info "  Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_info "=========================================="
    
    html_report="${OUTPUT_DIR}/${scenario}_${timestamp}.html"
    csv_prefix="${OUTPUT_DIR}/${scenario}_${timestamp}"
    
    # Run in headless mode with specific user class
    locust -f locustfile.py \
        --host="${HOST}" \
        --users="${users}" \
        --spawn-rate="${spawn_rate}" \
        --run-time="${run_time}" \
        --headless \
        --only-summary \
        --html="${html_report}" \
        --csv="${csv_prefix}" \
        ${user_class}
    
    local exit_code=$?
    
    echo ""
    print_info "  End Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    if [ $exit_code -eq 0 ]; then
        print_success "Test completed! Results saved:"
    else
        print_warning "Test completed with errors. Results saved:"
    fi
    
    print_info "  HTML Report: ${html_report}"
    print_info "  CSV Stats: ${csv_prefix}_stats.csv"
    print_info "  CSV Failures: ${csv_prefix}_failures.csv"
    echo ""
    
    return $exit_code
}

# Normal Load Test
# 5 concurrent users, spawn rate 1 user/sec, 30 seconds
# Expected: 100% success rate
run_normal_load() {
    print_info "📊 Normal Load Test Configuration:"
    print_info "   - 5 concurrent users"
    print_info "   - Spawn rate: 1 user/second"
    print_info "   - Duration: 30 seconds"
    print_info "   - Expected: 100% success rate"
    echo ""
    run_test "normal_operations" 5 1 "30s" "NormalLoadUser" "POST /orders/sync"
}

# Flash Sale Test (Sync)
# 20 concurrent users, spawn rate 10 users/sec, 60 seconds
# Question: What happens to your customers?
run_flash_sale_sync() {
    print_info "🔥 Flash Sale Test (Sync) Configuration:"
    print_info "   - 20 concurrent users"
    print_info "   - Spawn rate: 10 users/second"
    print_info "   - Duration: 60 seconds"
    print_info "   - Question: What happens to your customers?"
    echo ""
    run_test "flash_sale_sync" 20 10 "60s" "FlashSaleUser --tags sync" "POST /orders/sync"
}

# Flash Sale Test (Async)
# 20 concurrent users, spawn rate 10 users/sec, 60 seconds
# Expected: 100% acceptance rate!
run_flash_sale_async() {
    print_info "🚀 Flash Sale Test (Async) Configuration:"
    print_info "   - 20 concurrent users"
    print_info "   - Spawn rate: 10 users/second"
    print_info "   - Duration: 60 seconds"
    print_info "   - Expected: 100% acceptance rate!"
    echo ""
    run_test "flash_sale_async" 20 10 "60s" "FlashSaleUser --tags async" "POST /orders/async"
}

# Run all tests sequentially
run_all_tests() {
    print_info "Running all test scenarios sequentially..."
    
    echo ""
    print_info "🕐 Test Suite Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    local normal_exit=0
    local flash_sync_exit=0
    local flash_async_exit=0
    
    # Run normal load test
    run_normal_load
    normal_exit=$?
    
    print_info "Waiting 10 seconds before next test..."
    sleep 10
    
    # Run flash sale test (sync)
    run_flash_sale_sync
    flash_sync_exit=$?
    
    print_info "Waiting 10 seconds before next test..."
    sleep 10
    
    # Run flash sale test (async)
    run_flash_sale_async
    flash_async_exit=$?
    
    echo ""
    print_info "🕐 Test Suite End Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Summary of results
    print_info "=========================================="
    print_info "TEST SUITE SUMMARY"
    print_info "=========================================="
    
    if [ $normal_exit -eq 0 ]; then
        print_success "✓ Normal Load Test: PASSED"
    else
        print_warning "✗ Normal Load Test: FAILED (had failures or errors)"
    fi
    
    if [ $flash_sync_exit -eq 0 ]; then
        print_success "✓ Flash Sale Test (Sync): PASSED"
    else
        print_warning "✗ Flash Sale Test (Sync): FAILED (had failures or errors)"
    fi
    
    if [ $flash_async_exit -eq 0 ]; then
        print_success "✓ Flash Sale Test (Async): PASSED"
    else
        print_warning "✗ Flash Sale Test (Async): FAILED (had failures or errors)"
    fi
    
    echo ""
    print_info "Check ${OUTPUT_DIR}/ for detailed results"
    echo ""
    print_info "View CloudWatch logs:"
    print_info "  Receiver: aws logs tail /ecs/order-processing/order-receiver --region ${AWS_REGION} --follow"
    print_info "  Processor: aws logs tail /ecs/order-processing/order-processor --region ${AWS_REGION} --follow"
    echo ""
    
    # Show summary of generated reports
    print_info "📊 Generated Reports:"
    ls -lht "${OUTPUT_DIR}" | head -15
}

# Show usage
show_usage() {
    cat << EOF

${GREEN}Order Processing Service - Load Testing Script${NC}

${YELLOW}Usage:${NC}
    $0 [command]

${YELLOW}Commands:${NC}
    normal          Run normal operations test
                    - 5 concurrent users
                    - Spawn rate: 1 user/second
                    - Duration: 30 seconds
                    - Endpoint: POST /orders/sync
                    - Expected: 100% success rate
                    
    flash-sale-sync Run flash sale test (synchronous)
                    - 20 concurrent users
                    - Spawn rate: 10 users/second
                    - Duration: 60 seconds
                    - Endpoint: POST /orders/sync
                    - Question: What happens to your customers?
                    
    flash-sale-async Run flash sale test (asynchronous)
                    - 20 concurrent users
                    - Spawn rate: 10 users/second
                    - Duration: 60 seconds
                    - Endpoint: POST /orders/async
                    - Expected: 100% acceptance rate!
                    
    all             Run all test scenarios sequentially (recommended)
    web             Start Locust Web UI for manual testing
    check           Check API health

${YELLOW}Test Configuration:${NC}
    - Spawn rate: 1 user/second (normal), 10 users/second (flash)
    - User wait time: random 100-500ms between requests
    - Test endpoints: POST /orders/sync, POST /orders/async

${YELLOW}Examples:${NC}
    # Run all tests (recommended)
    $0 all

    # Run only normal load test
    $0 normal

    # Run sync flash sale test
    $0 flash-sale-sync

    # Run async flash sale test
    $0 flash-sale-async

    # Check if API is healthy
    $0 check

    # Start web UI for manual testing
    $0 web

${YELLOW}Output:${NC}
    Results are saved to: ${OUTPUT_DIR}/
    - HTML reports: *_TIMESTAMP.html
    - CSV stats: *_TIMESTAMP_stats.csv
    - CSV failures: *_TIMESTAMP_failures.csv

${YELLOW}Notes:${NC}
    - ALB DNS is automatically detected from deployment
    - Run ./deploy.sh first if you haven't deployed yet
    - Tests target /orders/sync endpoint only
    - Normal load test expects 100% success rate
    - Flash sale test demonstrates system behavior under high load

EOF
}

# Main script logic
main() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Order Processing Load Testing${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    
    check_locust
    get_alb_dns
    setup_output_dir
    
    case "${1:-}" in
        normal)
            check_api
            run_normal_load
            ;;
        flash-sale-sync)
            check_api
            run_flash_sale_sync
            ;;
        flash-sale-async)
            check_api
            run_flash_sale_async
            ;;
        flash-sale)
            # For backward compatibility
            check_api
            run_flash_sale_async
            ;;
        all)
            check_api
            run_all_tests
            ;;
        web)
            check_api
            print_info "Starting Locust Web UI..."
            print_info "Open http://localhost:8089 in your browser"
            locust -f locustfile.py --host="${HOST}"
            ;;
        check)
            check_api
            ;;
        help|--help|-h|"")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
