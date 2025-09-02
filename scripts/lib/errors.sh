#!/usr/bin/env bash
# Enhanced Error Messages Library
# Provides actionable error messages with suggested fixes

# Error with suggestion
# Usage: error_with_fix "error message" "suggested fix"
error_with_fix() {
    local error="$1"
    local fix="$2"
    
    log_error "$error"
    if [[ -n "$fix" ]]; then
        echo -e "${COLOR_YELLOW}  → Try: ${fix}${COLOR_RESET}" >&2
    fi
}

# Common error: Hardware configuration missing
error_hardware_missing() {
    error_with_fix \
        "Hardware configuration not found at hosts/nixos/hardware-configuration.nix" \
        "sudo nixos-generate-config --dir hosts/nixos/"
}

# Common error: Not in git repository
error_not_git_repo() {
    error_with_fix \
        "Not in a git repository (required for flakes)" \
        "git init && git add . && git commit -m 'Initial commit'"
}

# Common error: Flake not found
error_flake_missing() {
    error_with_fix \
        "flake.nix not found in current directory" \
        "cd to your NixOS configuration directory or create a flake.nix"
}

# Common error: SOPS not configured
error_sops_not_configured() {
    error_with_fix \
        "SOPS encryption not configured" \
        "./nix.sh sops"
}

# Common error: Age key missing
error_age_key_missing() {
    error_with_fix \
        "Age key not found at ~/.config/sops/age/keys.txt" \
        "age-keygen -o ~/.config/sops/age/keys.txt"
}

# Common error: Disk space low
error_disk_space_low() {
    local available="$1"
    error_with_fix \
        "Low disk space in /nix/store (${available}KB available)" \
        "./nix.sh clean -a"
}

# Common error: Service failed
error_service_failed() {
    local service="$1"
    error_with_fix \
        "Service $service failed to start" \
        "systemctl status $service && journalctl -xeu $service"
}

# Common error: Build failed
error_build_failed() {
    error_with_fix \
        "NixOS configuration build failed" \
        "./nix.sh test && ./nix.sh rebuild -v --show-trace"
}

# Common error: Test failed
error_test_failed() {
    local test="$1"
    local details="${2:-}"
    
    log_error "Test '$test' failed"
    
    case "$test" in
        syntax)
            error_with_fix \
                "" \
                "Check for syntax errors in .nix files"
            ;;
        flake)
            error_with_fix \
                "" \
                "nix flake check --show-trace"
            ;;
        build)
            error_with_fix \
                "" \
                "sudo nixos-rebuild dry-build --flake .#nixos --show-trace"
            ;;
        secrets)
            error_with_fix \
                "" \
                "./nix.sh sops && check .sops.yaml configuration"
            ;;
        hardware)
            error_with_fix \
                "" \
                "sudo nixos-generate-config --dir hosts/nixos/"
            ;;
        security)
            error_with_fix \
                "" \
                "Check for exposed passwords/secrets in .nix files"
            ;;
        *)
            [[ -n "$details" ]] && log_info "$details"
            ;;
    esac
}

# Common error: Command not found
error_command_not_found() {
    local command="$1"
    local package="${2:-$command}"
    
    error_with_fix \
        "Command '$command' not found" \
        "nix-env -iA nixpkgs.$package or add to configuration.nix"
}

# Common error: Permission denied
error_permission_denied() {
    local operation="$1"
    error_with_fix \
        "Permission denied for: $operation" \
        "Run with sudo or check file permissions"
}

# Common error: Network issues
error_network_failed() {
    local operation="$1"
    error_with_fix \
        "Network operation failed: $operation" \
        "Check internet connection and proxy settings"
}

# Common error: Flake input not found
error_flake_input_not_found() {
    local input="$1"
    error_with_fix \
        "Flake input '$input' not found" \
        "Check flake.nix inputs or run: nix flake update"
}

# Common error: Module conflict
error_module_conflict() {
    local module="$1"
    error_with_fix \
        "Module conflict detected in $module" \
        "Check for duplicate definitions or circular dependencies"
}

# Common error: State version mismatch
error_state_version() {
    local current="$1"
    local required="$2"
    error_with_fix \
        "State version mismatch: current=$current, required=$required" \
        "DO NOT change stateVersion without proper migration!"
}

# Common error: Git has unstaged changes
error_git_unstaged() {
    local count="$1"
    error_with_fix \
        "Git has $count unstaged changes (flakes need staged/committed files)" \
        "git add . or ./nix.sh rebuild (auto-stages)"
}

# Common error: Invalid option
error_invalid_option() {
    local option="$1"
    local command="${2:-}"
    
    if [[ -n "$command" ]]; then
        error_with_fix \
            "Invalid option '$option' for command '$command'" \
            "./nix.sh $command --help"
    else
        error_with_fix \
            "Invalid option '$option'" \
            "./nix.sh --help"
    fi
}

# Common error: Required file missing
error_file_missing() {
    local file="$1"
    local purpose="${2:-}"
    
    if [[ -n "$purpose" ]]; then
        error_with_fix \
            "Required file missing: $file ($purpose)" \
            "Create $file or check documentation"
    else
        error_with_fix \
            "Required file missing: $file" \
            "Create $file or check path"
    fi
}

# Export all error functions
export -f error_with_fix error_hardware_missing error_not_git_repo
export -f error_flake_missing error_sops_not_configured error_age_key_missing
export -f error_disk_space_low error_service_failed error_build_failed
export -f error_test_failed error_command_not_found error_permission_denied
export -f error_network_failed error_flake_input_not_found error_module_conflict
export -f error_state_version error_git_unstaged error_invalid_option
export -f error_file_missing