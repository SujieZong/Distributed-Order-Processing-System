#!/bin/bash
# verify_setup.sh
# Verify all prerequisites are met before running experiments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Phase 5 Experiment - Prerequisites Check${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

ERRORS=0

# Check 1: AWS CLI
echo -n "Checking AWS CLI... "
if command -v aws &> /dev/null; then
    VERSION=$(aws --version | cut -d' ' -f1)
    echo -e "${GREEN}✓ $VERSION${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: AWS Credentials
echo -n "Checking AWS credentials... "
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ Account: $ACCOUNT${NC}"
else
    echo -e "${RED}✗ Not configured${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
        echo -e "${GREEN}✓ Running ($VERSION)${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Terraform
echo -n "Checking Terraform... "
if command -v terraform &> /dev/null; then
    VERSION=$(terraform version | head -n1 | cut -d'v' -f2)
    echo -e "${GREEN}✓ v$VERSION${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 5: Python
echo -n "Checking Python... "
if command -v python3 &> /dev/null; then
    VERSION=$(python3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓ $VERSION${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 6: Locust
echo -n "Checking Locust... "
if python3 -c "import locust" 2>/dev/null; then
    VERSION=$(python3 -c "import locust; print(locust.__version__)")
    echo -e "${GREEN}✓ v$VERSION${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    echo -e "  ${YELLOW}Install with: pip install -r requirements.txt${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: jq (for monitor_queue.sh)
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    VERSION=$(jq --version | cut -d'-' -f2)
    echo -e "${GREEN}✓ $VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Not installed (recommended for queue monitoring)${NC}"
    echo -e "  ${YELLOW}Install with: brew install jq${NC}"
fi

# Check 8: Required files
echo ""
echo "Checking required files:"

FILES=(
    "quick_deploy.sh"
    "run_single_experiment.sh"
    "run_all_experiments.sh"
    "monitor_queue.sh"
    "locustfile.py"
    "terraform/main.tf"
    "terraform/variables.tf"
    "src/main.go"
    "src/Dockerfile"
)

for FILE in "${FILES[@]}"; do
    echo -n "  $FILE... "
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check 9: Script permissions
echo ""
echo "Checking script permissions:"

SCRIPTS=(
    "quick_deploy.sh"
    "run_single_experiment.sh"
    "run_all_experiments.sh"
    "monitor_queue.sh"
)

for SCRIPT in "${SCRIPTS[@]}"; do
    echo -n "  $SCRIPT... "
    if [ -x "$SCRIPT" ]; then
        echo -e "${GREEN}✓ Executable${NC}"
    else
        echo -e "${YELLOW}⚠ Not executable${NC}"
        chmod +x "$SCRIPT"
        echo -e "    ${GREEN}Fixed!${NC}"
    fi
done

# Summary
echo ""
echo -e "${BLUE}================================================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! You're ready to run experiments.${NC}"
    echo ""
    echo -e "${YELLOW}Quick Start:${NC}"
    echo "  1. Deploy infrastructure:"
    echo "     ${GREEN}./quick_deploy.sh${NC}"
    echo ""
    echo "  2. Run single experiment:"
    echo "     ${GREEN}./run_single_experiment.sh 1 120${NC}"
    echo ""
    echo "  3. Or run all experiments:"
    echo "     ${GREEN}./run_all_experiments.sh${NC}"
    echo ""
    echo -e "${YELLOW}Documentation:${NC}"
    echo "  • Quick start guide: ${GREEN}cat EXPERIMENT_QUICKSTART.md${NC}"
    echo "  • Detailed guide: ${GREEN}cat PHASE5_EXPERIMENT_GUIDE.md${NC}"
else
    echo -e "${RED}✗ Found $ERRORS error(s). Please fix them before proceeding.${NC}"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  • Install AWS CLI: https://aws.amazon.com/cli/"
    echo "  • Configure AWS credentials: aws configure"
    echo "  • Install Docker: https://www.docker.com/products/docker-desktop"
    echo "  • Install Terraform: https://www.terraform.io/downloads"
    echo "  • Install Python packages: pip install -r requirements.txt"
    exit 1
fi

echo -e "${BLUE}================================================================${NC}"
echo ""
