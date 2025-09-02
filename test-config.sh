#!/usr/bin/env bash
# NixOS Configuration Testing and Validation Script

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

# Functions
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

pass_test() {
    echo -e "${GREEN}  ✓${NC} $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}  ✗${NC} $1"
    ((TESTS_FAILED++))
}

warn_test() {
    echo -e "${YELLOW}  ⚠${NC} $1"
    ((WARNINGS++))
}

# Test Nix syntax
test_nix_syntax() {
    print_test "Checking Nix syntax..."
    
    local files=$(find . -name "*.nix" -type f)
    local errors=0
    
    for file in $files; do
        if nix-instantiate --parse "$file" &>/dev/null; then
            pass_test "$file"
        else
            fail_test "$file has syntax errors"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        pass_test "All Nix files have valid syntax"
    fi
}

# Test flake validity
test_flake() {
    print_test "Validating flake..."
    
    if nix flake check --no-build 2>/dev/null; then
        pass_test "Flake structure is valid"
    else
        fail_test "Flake check failed"
    fi
    
    if nix flake show &>/dev/null; then
        pass_test "Flake outputs are accessible"
    else
        fail_test "Cannot show flake outputs"
    fi
}

# Test configuration build
test_build() {
    print_test "Testing configuration build..."
    
    if sudo nixos-rebuild dry-build --flake .#nixos 2>/dev/null; then
        pass_test "Configuration builds successfully"
    else
        fail_test "Configuration build failed"
    fi
}

# Test module imports
test_modules() {
    print_test "Checking module imports..."
    
    local modules=$(grep -r "imports = \[" --include="*.nix" | wc -l)
    if [ $modules -gt 0 ]; then
        pass_test "Found $modules module import statements"
    else
        warn_test "No module imports found"
    fi
    
    # Check for circular dependencies
    if nix-instantiate --eval -E "(import ./flake.nix).nixosConfigurations.nixos.config" &>/dev/null; then
        pass_test "No circular dependencies detected"
    else
        fail_test "Possible circular dependency in modules"
    fi
}

# Test secret files
test_secrets() {
    print_test "Checking secrets configuration..."
    
    if [ -f ".sops.yaml" ]; then
        pass_test ".sops.yaml exists"
        
        if grep -q "age1" .sops.yaml; then
            pass_test "Age keys configured in .sops.yaml"
        else
            warn_test "No age keys found in .sops.yaml"
        fi
    else
        fail_test ".sops.yaml not found"
    fi
    
    if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
        pass_test "User age key exists"
    else
        warn_test "User age key not found"
    fi
}

# Test hardware configuration
test_hardware() {
    print_test "Checking hardware configuration..."
    
    if [ -f "hosts/nixos/hardware-configuration.nix" ]; then
        pass_test "Hardware configuration exists"
    elif [ -f "hardware-configuration.nix" ]; then
        pass_test "Hardware configuration exists (root)"
    else
        fail_test "Hardware configuration not found"
    fi
}

# Test user configuration
test_users() {
    print_test "Checking user configuration..."
    
    if [ -f "users/semyenov/home.nix" ]; then
        pass_test "User home configuration exists"
        
        if grep -q "stateVersion" users/semyenov/home.nix; then
            pass_test "Home Manager state version set"
        else
            fail_test "Home Manager state version not set"
        fi
    else
        fail_test "User home configuration not found"
    fi
}

# Test for common issues
test_common_issues() {
    print_test "Checking for common issues..."
    
    # Check for TODO comments
    local todos=$(grep -r "TODO\|FIXME\|XXX" --include="*.nix" | wc -l)
    if [ $todos -gt 0 ]; then
        warn_test "Found $todos TODO/FIXME comments"
    else
        pass_test "No TODO/FIXME comments found"
    fi
    
    # Check for hardcoded paths
    if grep -r "/home/semyenov" --include="*.nix" | grep -v "homeDirectory\|/home/semyenov/.config" &>/dev/null; then
        warn_test "Found hardcoded home paths"
    else
        pass_test "No hardcoded paths found"
    fi
    
    # Check for missing EOF newlines
    local missing_newlines=0
    for file in $(find . -name "*.nix" -type f); do
        if [ -n "$(tail -c 1 "$file")" ]; then
            warn_test "$file missing final newline"
            ((missing_newlines++))
        fi
    done
    
    if [ $missing_newlines -eq 0 ]; then
        pass_test "All files have proper EOF newlines"
    fi
}

# Test formatting
test_formatting() {
    print_test "Checking code formatting..."
    
    if command -v nixpkgs-fmt &>/dev/null; then
        local unformatted=0
        for file in $(find . -name "*.nix" -type f); do
            if ! nixpkgs-fmt --check "$file" &>/dev/null; then
                warn_test "$file needs formatting"
                ((unformatted++))
            fi
        done
        
        if [ $unformatted -eq 0 ]; then
            pass_test "All files are properly formatted"
        else
            warn_test "$unformatted files need formatting (run: nixpkgs-fmt .)"
        fi
    else
        warn_test "nixpkgs-fmt not installed, skipping format check"
    fi
}

# Test for unused code
test_unused() {
    print_test "Checking for unused code..."
    
    if command -v deadnix &>/dev/null; then
        local dead_code=$(deadnix . 2>/dev/null | wc -l)
        if [ $dead_code -gt 0 ]; then
            warn_test "Found potential dead code (run: deadnix .)"
        else
            pass_test "No dead code detected"
        fi
    else
        warn_test "deadnix not installed, skipping dead code check"
    fi
}

# Test security
test_security() {
    print_test "Checking security configuration..."
    
    # Check firewall
    if grep -r "networking.firewall.enable = true" --include="*.nix" &>/dev/null; then
        pass_test "Firewall is enabled"
    else
        fail_test "Firewall might be disabled"
    fi
    
    # Check SSH hardening
    if grep -r "PermitRootLogin = \"no\"" --include="*.nix" &>/dev/null; then
        pass_test "SSH root login disabled"
    else
        warn_test "SSH root login might be enabled"
    fi
    
    # Check for exposed secrets
    if grep -r "password\|secret\|token\|key" --include="*.nix" | grep -v "sops\|age\|ssh\|gnupg\|passwordAuthentication" | grep "=" &>/dev/null; then
        fail_test "Possible exposed secrets found!"
    else
        pass_test "No exposed secrets detected"
    fi
}

# Performance test
test_performance() {
    print_test "Checking performance settings..."
    
    if grep -r "zramSwap.enable = true" --include="*.nix" &>/dev/null; then
        pass_test "ZRAM swap enabled"
    else
        warn_test "ZRAM swap not enabled"
    fi
    
    if grep -r "auto-optimise-store = true" --include="*.nix" &>/dev/null; then
        pass_test "Nix store auto-optimization enabled"
    else
        warn_test "Nix store auto-optimization not enabled"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}NixOS Configuration Validation${NC}"
    echo "================================"
    echo
    
    test_nix_syntax
    echo
    test_flake
    echo
    test_build
    echo
    test_modules
    echo
    test_secrets
    echo
    test_hardware
    echo
    test_users
    echo
    test_common_issues
    echo
    test_formatting
    echo
    test_unused
    echo
    test_security
    echo
    test_performance
    echo
    
    # Summary
    echo "================================"
    echo -e "${BLUE}Test Summary${NC}"
    echo "================================"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Configuration has errors that need to be fixed!${NC}"
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}Configuration is valid but has warnings to review${NC}"
        exit 0
    else
        echo -e "${GREEN}Configuration validation successful!${NC}"
        exit 0
    fi
}

# Run tests
main "$@"