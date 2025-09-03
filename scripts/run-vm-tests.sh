#!/usr/bin/env bash
# VM Test Runner with Environment Detection
# Provides better feedback and cross-platform compatibility

set -euo pipefail

echo "Running NixOS VM Tests"
echo "======================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

EXIT_CODE=0

# Detect system architecture and OS
SYSTEM=$(nix eval --impure --expr 'builtins.currentSystem' 2>/dev/null | tr -d '"' || echo "unknown")
echo "Detected system: $SYSTEM"

# Check if we're on a Linux system that can run VM tests
if [[ "$SYSTEM" == *"linux"* ]]; then
    echo -e "${GREEN}✓ Linux system detected - VM tests can run natively${NC}"
    NATIVE_VM=true
else
    echo -e "${YELLOW}⚠ Non-Linux system ($SYSTEM) - VM tests will be mocked${NC}"
    NATIVE_VM=false
fi

echo ""

# Function to run a single VM test
run_vm_test() {
    local test_file=$1
    local test_name=$2
    
    echo "Testing: $test_name"
    echo "------------------------------"
    
    if $NATIVE_VM; then
        echo "  Running native VM test..."
        if nix-build "$test_file" --no-out-link >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ VM test passed${NC}"
        else
            echo -e "  ${RED}✗ VM test failed${NC}"
            EXIT_CODE=1
        fi
    else
        echo "  Building mock test (cross-platform)..."
        OUTPUT=$(nix-build "$test_file" --no-out-link 2>/dev/null)
        if [[ -f "$OUTPUT" ]]; then
            echo -e "  ${BLUE}⚠ Test skipped (cross-platform)${NC}"
            echo "  Reason: $(head -1 "$OUTPUT")"
            echo "  Would test: $(tail -1 "$OUTPUT" | cut -d: -f2- | xargs)"
        else
            echo -e "  ${RED}✗ Mock test build failed${NC}"
            EXIT_CODE=1
        fi
    fi
    echo ""
}

# Get list of VM tests
TEST_DIR="$(dirname "$0")/../tests/vm"

if [[ ! -d "$TEST_DIR" ]]; then
    echo -e "${RED}✗ VM tests directory not found: $TEST_DIR${NC}"
    exit 1
fi

# Count tests
TOTAL_TESTS=$(find "$TEST_DIR" -name "*.nix" | wc -l | tr -d ' ')
echo "Found $TOTAL_TESTS VM tests"
echo ""

# Run each test
for test_file in "$TEST_DIR"/*.nix; do
    if [[ -f "$test_file" ]]; then
        test_name=$(basename "$test_file" .nix)
        run_vm_test "$test_file" "$test_name"
    fi
done

echo "========================"
echo "VM Test Summary:"

if [[ $EXIT_CODE -eq 0 ]]; then
    if $NATIVE_VM; then
        echo -e "${GREEN}✓ All $TOTAL_TESTS VM tests passed!${NC}"
    else
        echo -e "${BLUE}⚠ All $TOTAL_TESTS VM tests validated (mocked on $SYSTEM)${NC}"
        echo "  Run on Linux system for native VM testing"
    fi
else
    echo -e "${RED}✗ Some VM tests failed${NC}"
fi

echo ""
echo "VM Test Coverage:"
echo "  Backup Service:"
echo "    • Service configuration and lifecycle"
echo "    • Repository creation and backup operations"
echo "    • Scheduled backup execution"
echo "  Firewall Configuration:"
echo "    • iptables rules and port management"
echo "    • fail2ban integration and intrusion detection"
echo "    • Service isolation and security"
echo "  Monitoring Stack:"
echo "    • Prometheus metrics collection"
echo "    • Grafana dashboard functionality"
echo "    • Alert manager configuration"
echo "  Performance Optimizations:"
echo "    • ZRAM compression and swap management"
echo "    • Kernel parameter tuning"
echo "    • Filesystem optimizations"
echo "  V2Ray Secrets Service:"
echo "    • SOPS secrets integration"
echo "    • Service startup and configuration"
echo "    • Proxy functionality and security"

exit $EXIT_CODE