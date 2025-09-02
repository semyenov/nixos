#!/usr/bin/env bash
# Test Functions Library
# Provides test functions for NixOS configuration validation

# Test: Nix syntax validation
test_syntax() {
    log_debug "Checking Nix syntax in all .nix files..."
    find . -name "*.nix" -type f -exec nix-instantiate --parse {} \; >/dev/null 2>&1
}

# Test: Flake validation
test_flake() {
    log_debug "Validating flake structure..."
    [[ -f "flake.nix" ]] || return 2  # Skip if no flake
    nix flake check --no-build 2>/dev/null
}

# Test: Configuration build
test_build() {
    log_debug "Testing configuration build..."
    command_exists nixos-rebuild || return 2  # Skip if not on NixOS
    sudo nixos-rebuild dry-build --flake "${FLAKE_REF:-'.#nixos'}" 2>/dev/null
}

# Test: Module imports
test_modules() {
    log_debug "Checking module imports..."
    nix-instantiate --eval -E "(import ./flake.nix).nixosConfigurations.nixos.config" >/dev/null 2>&1
}

# Test: Secrets configuration
test_secrets() {
    log_debug "Validating secrets configuration..."
    
    # Check .sops.yaml exists
    [[ -f ".sops.yaml" ]] || return 1
    
    # Check for age keys
    grep -q "age1" .sops.yaml || return 1
    
    # Check user age key exists
    [[ -f "$HOME/.config/sops/age/keys.txt" ]] || return 2  # Skip if not configured
    
    return 0
}

# Test: Hardware configuration
test_hardware() {
    log_debug "Checking hardware configuration..."
    
    local hw_config="hosts/nixos/hardware-configuration.nix"
    [[ -f "$hw_config" ]] || hw_config="hardware-configuration.nix"
    
    if [[ ! -f "$hw_config" ]]; then
        log_warn "Hardware configuration not found"
        return 2  # Skip
    fi
    
    nix-instantiate --parse "$hw_config" >/dev/null 2>&1
}

# Test: Security settings
test_security() {
    log_debug "Checking for exposed secrets..."
    
    # Look for potential exposed secrets in Nix files
    ! grep -r "password\|secret\|token\|key" --include="*.nix" | \
        grep -v "sops\|age\|ssh\|gnupg\|passwordAuthentication" | \
        grep "=" >/dev/null 2>&1
}

# Test: Performance settings
test_performance() {
    log_debug "Checking performance optimizations..."
    
    local warnings=0
    
    # Check for ZRAM
    if ! grep -r "zramSwap.enable = true" --include="*.nix" >/dev/null 2>&1; then
        log_debug "ZRAM swap not enabled"
        ((warnings++))
    fi
    
    # Check for store optimization
    if ! grep -r "auto-optimise-store = true" --include="*.nix" >/dev/null 2>&1; then
        log_debug "Nix store auto-optimization not enabled"
        ((warnings++))
    fi
    
    [[ $warnings -eq 0 ]]
}

# Test: Shell scripts validation
test_shellcheck() {
    log_debug "Running ShellCheck on shell scripts..."
    
    command_exists shellcheck || return 2  # Skip if not installed
    
    local errors=0
    local scripts
    scripts=$(find . -name "*.sh" -type f 2>/dev/null)
    
    for script in $scripts; do
        if ! shellcheck -S warning "$script" >/dev/null 2>&1; then
            log_debug "ShellCheck warnings in $script"
            ((errors++))
        fi
    done
    
    [[ $errors -eq 0 ]]
}

# Test: Code formatting
test_formatting() {
    log_debug "Checking Nix code formatting..."
    
    command_exists nixpkgs-fmt || return 2  # Skip if not installed
    
    local unformatted=0
    local files
    files=$(find . -name "*.nix" -type f 2>/dev/null)
    
    for file in $files; do
        if ! nixpkgs-fmt --check "$file" >/dev/null 2>&1; then
            log_debug "$file needs formatting"
            ((unformatted++))
        fi
    done
    
    [[ $unformatted -eq 0 ]]
}

# Run a single test and return status
# Usage: run_test "test_name" "Display Name"
# Returns: 0=passed, 1=failed, 2=skipped
run_single_test() {
    local test_name="$1"
    local display_name="${2:-$1}"
    
    if ! declare -f "$test_name" >/dev/null; then
        log_error "Test function $test_name not found"
        return 1
    fi
    
    local start_time
    start_time=$(date +%s)
    
    local output
    local exit_code
    
    output=$("$test_name" 2>&1)
    exit_code=$?
    
    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - start_time ))
    
    case $exit_code in
        0)
            print_success "$display_name (${duration}s)"
            return 0
            ;;
        2)
            print_warning "$display_name - SKIPPED"
            return 2
            ;;
        *)
            print_error "$display_name (${duration}s)"
            [[ -n "$output" ]] && echo "$output" | sed 's/^/  /'
            return 1
            ;;
    esac
}

# Get all available test names
get_available_tests() {
    declare -F | grep "^declare -f test_" | awk '{print $3}' | sed 's/^test_//'
}

# Validate test name
is_valid_test() {
    local test="$1"
    declare -f "test_$test" >/dev/null
}

# Export all test functions
export -f test_syntax test_flake test_build test_modules
export -f test_secrets test_hardware test_security test_performance
export -f test_shellcheck test_formatting
export -f run_single_test get_available_tests is_valid_test