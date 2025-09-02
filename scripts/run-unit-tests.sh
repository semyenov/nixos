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

# Run module-utils tests
echo "Testing: lib/module-utils.nix"
echo "------------------------------"

# Get test counts
TOTAL=$(nix-instantiate --eval tests/unit/module-utils.nix -A summary.total 2>/dev/null)
PASSED=$(nix-instantiate --eval tests/unit/module-utils.nix -A summary.passed 2>/dev/null)
FAILED=$(nix-instantiate --eval tests/unit/module-utils.nix -A summary.failed 2>/dev/null)

echo "  Total tests: $TOTAL"
echo "  Passed: ${GREEN}$PASSED${NC}"
echo "  Failed: ${RED}$FAILED${NC}"

# Get overall result
RESULT=$(nix-instantiate --eval tests/unit/module-utils.nix -A result 2>/dev/null | sed 's/^"//' | sed 's/"$//')

echo ""
if echo "$RESULT" | grep -q "All tests passed"; then
    echo -e "${GREEN}✓ $RESULT${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}✗ $RESULT${NC}"
    # Show failures if any
    echo ""
    echo "Failed tests:"
    nix-instantiate --eval tests/unit/module-utils.nix -A failures 2>/dev/null || true
    EXIT_CODE=1
fi

echo ""
echo "========================"
echo "Test Categories:"
echo "  • mkPortOption - Port configuration helper"
echo "  • mkPercentageOption - Percentage value helper"
echo "  • validators - Email, IP, port validation"
echo "  • mkAssertion - Assertion builder"
echo "  • mkScheduleOption - Systemd timer helper"

exit $EXIT_CODE