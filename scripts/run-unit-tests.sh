#!/usr/bin/env bash
# Unit test runner with detailed output

set -euo pipefail

echo "Running NixOS Unit Tests"
echo "========================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

EXIT_CODE=0

# Function to run a test file
run_test() {
    local test_file=$1
    local test_name=$2
    
    echo "Testing: $test_name"
    echo "------------------------------"
    
    # Get test counts
    TOTAL=$(nix-instantiate --eval "$test_file" -A summary.total 2>/dev/null)
    PASSED=$(nix-instantiate --eval "$test_file" -A summary.passed 2>/dev/null)
    FAILED=$(nix-instantiate --eval "$test_file" -A summary.failed 2>/dev/null)
    
    echo "  Total tests: $TOTAL"
    echo -e "  Passed: ${GREEN}$PASSED${NC}"
    echo -e "  Failed: ${RED}$FAILED${NC}"
    
    # Get overall result
    RESULT=$(nix-instantiate --eval "$test_file" -A result 2>/dev/null | sed 's/^"//g' | sed 's/"$//g')
    
    echo ""
    if echo "$RESULT" | grep -q "passed"; then
        echo -e "${GREEN}✓ $RESULT${NC}"
    else
        echo -e "${RED}✗ $RESULT${NC}"
        # Show failures if any
        echo ""
        echo "Failed tests:"
        nix-instantiate --eval "$test_file" -A failures --strict 2>/dev/null || true
        EXIT_CODE=1
    fi
    echo ""
}

# Run all test files
run_test "tests/unit/module-utils.nix" "lib/module-utils.nix"
run_test "tests/unit/validators.nix" "lib/validators.nix"
run_test "tests/unit/v2ray-secrets.nix" "modules/services/network/v2ray-secrets.nix"

echo "========================"
echo "Test Summary:"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All unit tests passed!${NC}"
else
    echo -e "${RED}✗ Some tests failed${NC}"
fi
echo ""
echo "Test Coverage:"
echo "  Module Utils:"
echo "    • mkPortOption - Port configuration helper"
echo "    • mkPercentageOption - Percentage value helper"
echo "    • validators - Email, IP, port validation"
echo "    • mkAssertion - Assertion builder"
echo "    • mkScheduleOption - Systemd timer helper"
echo "  Validators:"
echo "    • Service dependency validation"
echo "    • Path existence checks"
echo "    • Memory size validation"
echo "    • User/group validation"
echo "  V2Ray Secrets:"
echo "    • Module options and configuration"
echo "    • SOPS secrets integration"
echo "    • Service dependencies and security"
echo "    • Systemd service generation"

exit $EXIT_CODE