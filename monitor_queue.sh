#!/bin/bash
# monitor_queue.sh
# Monitors SQS queue depth and processor metrics in real-time

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SQS Queue Monitor ===${NC}"
echo ""

# Get SQS Queue URL from Terraform output
cd terraform
QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "")
cd ..

if [ -z "$QUEUE_URL" ]; then
    echo -e "${RED}Error: Could not get SQS queue URL from Terraform${NC}"
    echo "Run: cd terraform && terraform output sqs_queue_url"
    exit 1
fi

echo -e "${GREEN}Queue URL: ${QUEUE_URL}${NC}"
echo ""

# Log file
LOG_FILE="reports/queue_metrics_$(date +%Y%m%d_%H%M%S).csv"
mkdir -p reports

# Write CSV header
echo "timestamp,visible_messages,in_flight_messages,total_messages" > "$LOG_FILE"

echo -e "${YELLOW}Monitoring queue depth... (Press Ctrl+C to stop)${NC}"
echo -e "${YELLOW}Logging to: ${LOG_FILE}${NC}"
echo ""
printf "%-20s | %-15s | %-15s | %-15s\n" "Timestamp" "Visible" "In-Flight" "Total"
echo "--------------------------------------------------------------------------------"

# Monitor loop
while true; do
    # Get queue attributes
    RESULT=$(aws sqs get-queue-attributes \
        --queue-url "$QUEUE_URL" \
        --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
        --output json 2>/dev/null || echo "{}")
    
    # Parse values
    VISIBLE=$(echo "$RESULT" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"')
    IN_FLIGHT=$(echo "$RESULT" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible // "0"')
    TOTAL=$((VISIBLE + IN_FLIGHT))
    
    # Timestamp
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Color code based on queue depth
    if [ "$TOTAL" -gt 100 ]; then
        COLOR=$RED
    elif [ "$TOTAL" -gt 20 ]; then
        COLOR=$YELLOW
    else
        COLOR=$GREEN
    fi
    
    # Display
    printf "${COLOR}%-20s | %-15s | %-15s | %-15s${NC}\n" \
        "$TIMESTAMP" "$VISIBLE" "$IN_FLIGHT" "$TOTAL"
    
    # Log to CSV
    echo "$TIMESTAMP,$VISIBLE,$IN_FLIGHT,$TOTAL" >> "$LOG_FILE"
    
    # Wait before next check
    sleep 5
done
