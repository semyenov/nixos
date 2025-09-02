#!/usr/bin/env bash
# Unified NixOS Management Script
# Single entrypoint for all NixOS configuration operations

# Source common library and new modules
NIX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$NIX_SCRIPT_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/dry-run.sh
source "$NIX_SCRIPT_DIR/scripts/lib/dry-run.sh"
# shellcheck source=scripts/lib/help.sh
source "$NIX_SCRIPT_DIR/scripts/lib/help.sh"
# shellcheck source=scripts/lib/options.sh
source "$NIX_SCRIPT_DIR/scripts/lib/options.sh"
# shellcheck source=scripts/lib/git.sh
source "$NIX_SCRIPT_DIR/scripts/lib/git.sh"
# shellcheck source=scripts/lib/tests.sh
source "$NIX_SCRIPT_DIR/scripts/lib/tests.sh"
# shellcheck source=scripts/lib/errors.sh
source "$NIX_SCRIPT_DIR/scripts/lib/errors.sh"

# Script configuration
readonly SCRIPT_NAME="NixOS Manager"
readonly VERSION="2.1.0"
readonly FLAKE_PATH="${FLAKE_PATH:-$PROJECT_ROOT}"
readonly HOSTNAME="${HOSTNAME:-nixos}"
readonly FLAKE_REF="${FLAKE_PATH}#${HOSTNAME}"

# Global options (will be set by option parser)
DRY_RUN=false
VERBOSE=false
FORCE=false
AUTO_YES=false

# ========================
# Rebuild Command
# ========================

cmd_rebuild() {
    # Check for help first
    if is_help_requested "$@"; then
        show_rebuild_help
        return 0
    fi
    
    # Parse options
    parse_rebuild_options "$@"
    
    print_header "NixOS Rebuild: ${REBUILD_OPERATION}"
    show_dry_run_warning
    
    # Prepare git repository
    prepare_git_for_rebuild "$REBUILD_NO_STAGE" "$REBUILD_NO_COMMIT"
    
    # Update flake if requested
    if [[ "$REBUILD_UPGRADE" == "true" ]]; then
        log_info "Updating flake inputs..."
        run_nix "flake update '$FLAKE_PATH'" "Update flake inputs"
        add_file_to_git "$FLAKE_PATH/flake.lock"
        print_success "Flake inputs updated"
    fi
    
    # Check disk space
    local available
    available=$(df /nix/store | tail -1 | awk '{print $4}')
    if [[ $available -lt 5000000 ]]; then
        error_disk_space_low "$available"
        if confirm "Run garbage collection?" "y"; then
            cmd_clean
        fi
    fi
    
    # Perform rebuild
    local rebuild_args=("$REBUILD_OPERATION" "--flake" "$FLAKE_REF")
    [[ "$REBUILD_SHOW_TRACE" == "true" ]] && rebuild_args+=("--show-trace")
    
    log_info "Building configuration..."
    if run_nixos_rebuild "$REBUILD_OPERATION" "${rebuild_args[*]:1}"; then
        print_success "Rebuild successful!"
        
        # Show new generation
        if ! is_dry_run; then
            local new_gen
            new_gen=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1)
            log_info "New generation: $new_gen"
            
            # Check if reboot needed
            local current_kernel running_kernel
            current_kernel=$(readlink /run/current-system/kernel | xargs basename)
            running_kernel=$(uname -r)
            
            if [[ "$current_kernel" != *"$running_kernel"* ]]; then
                log_warn "Kernel updated. Reboot recommended."
            fi
        fi
    else
        error_build_failed
        return 1
    fi
}

# ========================
# Setup Command
# ========================

cmd_setup() {
    # Check for help first
    if is_help_requested "$@"; then
        show_setup_help
        return 0
    fi
    
    # Parse options
    parse_setup_options "$@"
    
    print_header "NixOS Setup Wizard"
    show_dry_run_warning
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    if ! check_requirements git age ssh-to-age sops nix; then
        error_command_not_found "missing requirements" "see above"
        return 1
    fi
    
    if [[ ! -f "flake.nix" ]]; then
        error_flake_missing
        return 1
    fi
    print_success "Prerequisites satisfied"
    
    # Initialize git if needed
    init_git_repo || return 1
    
    # Generate hardware configuration
    if [[ "$SETUP_SKIP_HARDWARE" != "true" ]]; then
        local hw_config="hosts/nixos/hardware-configuration.nix"
        
        if [[ -f "$hw_config" ]]; then
            log_warn "Hardware configuration exists"
            if confirm "Regenerate hardware configuration?" "n"; then
                run_sudo "nixos-generate-config --dir '$(dirname "$hw_config")'" \
                    "Generate hardware configuration"
                add_file_to_git "$hw_config"
            fi
        else
            log_info "Generating hardware configuration..."
            run_file_op "mkdir" "$(dirname "$hw_config")" "Create hosts/nixos directory"
            run_sudo "nixos-generate-config --dir '$(dirname "$hw_config")'" \
                "Generate hardware configuration"
            add_file_to_git "$hw_config"
        fi
        print_success "Hardware configuration ready"
    fi
    
    # Setup SOPS
    if [[ "$SETUP_SKIP_SOPS" != "true" ]]; then
        cmd_sops
    fi
    
    # Test configuration
    if [[ "$SETUP_SKIP_TEST" != "true" ]]; then
        log_info "Testing configuration..."
        if ! is_dry_run; then
            if nix flake check --no-build 2>/dev/null; then
                print_success "Configuration valid"
            else
                error_test_failed "flake"
                return 1
            fi
        fi
    fi
    
    # Build configuration
    if [[ "$SETUP_SKIP_BUILD" != "true" ]]; then
        if confirm "Build configuration?" "y"; then
            run_nixos_rebuild "build" "--flake '$FLAKE_REF'"
            print_success "Configuration built"
        fi
    fi
    
    # Apply configuration
    log_warn "Ready to apply configuration"
    if confirm "Apply configuration now?" "n"; then
        cmd_rebuild
    else
        log_info "To apply later, run: $(basename "$0") rebuild"
    fi
    
    print_success "Setup complete!"
}

# ========================
# Test Command
# ========================

cmd_test() {
    # Check for help first
    if is_help_requested "$@"; then
        show_test_help
        return 0
    fi
    
    # Parse options
    parse_test_options "$@"
    
    print_header "Configuration Validation"
    show_dry_run_warning
    
    local passed=0
    local failed=0
    local skipped=0
    
    # Convert test list string to array
    IFS=' ' read -ra tests_to_run <<< "$TEST_TO_RUN"
    
    # Run tests
    for test in "${tests_to_run[@]}"; do
        if is_dry_run; then
            log_info "[DRY RUN] Would run test: $test"
        else
            local result
            run_single_test "test_$test" "$test"
            result=$?
            
            case $result in
                0) ((passed++)) ;;
                2) ((skipped++)) ;;
                *) 
                    ((failed++))
                    [[ "$TEST_FAIL_FAST" == "true" ]] && break
                    ;;
            esac
        fi
    done
    
    # Summary
    echo
    if [[ "$TEST_FORMAT" == "terminal" ]]; then
        log_info "Tests passed: $passed"
        [[ $failed -gt 0 ]] && log_error "Tests failed: $failed"
        [[ $skipped -gt 0 ]] && log_warn "Tests skipped: $skipped"
        
        if [[ $failed -gt 0 ]]; then
            print_error "Configuration has errors!"
            return 1
        else
            print_success "Configuration valid!"
        fi
    elif [[ "$TEST_FORMAT" == "json" ]]; then
        echo "{\"passed\":$passed,\"failed\":$failed,\"skipped\":$skipped}"
    fi
}

# ========================
# Update Command
# ========================

cmd_update() {
    # Check for help first
    if is_help_requested "$@"; then
        show_update_help
        return 0
    fi
    
    # Parse options
    parse_update_options "$@"
    
    print_header "Update Flake Inputs"
    show_dry_run_warning
    
    if [[ -n "$UPDATE_INPUT" ]]; then
        log_info "Updating input: $UPDATE_INPUT"
        run_nix "flake lock --update-input '$UPDATE_INPUT'" "Update $UPDATE_INPUT"
    else
        log_info "Updating all inputs..."
        run_nix "flake update" "Update all flake inputs"
    fi
    
    if ! is_dry_run; then
        add_file_to_git "flake.lock"
        print_success "Flake inputs updated"
        
        log_info "Current inputs:"
        nix flake metadata --json | jq -r '.locks.nodes.root.inputs | to_entries[] | "  - \(.key)"' 2>/dev/null || true
    fi
}

# ========================
# Clean Command
# ========================

cmd_clean() {
    # Check for help first
    if is_help_requested "$@"; then
        show_clean_help
        return 0
    fi
    
    # Parse options
    parse_clean_options "$@"
    
    print_header "System Cleanup"
    show_dry_run_warning
    
    # Show current disk usage
    log_info "Current /nix/store usage:"
    df -h /nix/store | tail -1
    
    # Delete old generations
    if [[ $CLEAN_KEEP_GENERATIONS -eq 0 ]]; then
        log_info "Deleting all old generations..."
        run_sudo "nix-collect-garbage -d" "Delete all old generations"
    else
        log_info "Keeping $CLEAN_KEEP_GENERATIONS most recent generations..."
        run_sudo "nix-env --delete-generations +$CLEAN_KEEP_GENERATIONS --profile /nix/var/nix/profiles/system" \
            "Delete old generations"
        run_sudo "nix-collect-garbage" "Collect garbage"
    fi
    
    # Optimize store
    log_info "Optimizing Nix store..."
    run_command "nix-store --optimise" "Optimize Nix store"
    
    if ! is_dry_run; then
        # Show new disk usage
        log_info "New /nix/store usage:"
        df -h /nix/store | tail -1
    fi
    
    print_success "Cleanup complete!"
}

# ========================
# Rollback Command
# ========================

cmd_rollback() {
    # Check for help first
    if is_help_requested "$@"; then
        show_rollback_help
        return 0
    fi
    
    print_header "System Rollback"
    show_dry_run_warning
    
    # Show current generation
    local current_gen
    current_gen=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep current | awk '{print $1}')
    log_info "Current generation: $current_gen"
    
    # Show available generations
    log_info "Available generations:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -5
    
    if confirm "Rollback to previous generation?" "y"; then
        run_nixos_rebuild "switch" "--rollback"
        print_success "Rollback complete!"
    fi
}

# ========================
# SOPS Command
# ========================

cmd_sops() {
    # Check for help first
    if is_help_requested "$@"; then
        show_sops_help
        return 0
    fi
    
    print_header "SOPS Encryption Setup"
    show_dry_run_warning
    
    local age_key_file="$HOME/.config/sops/age/keys.txt"
    
    # Generate age key if needed
    if [[ -f "$age_key_file" ]]; then
        log_warn "Age key already exists"
        if ! confirm "Generate new age key?" "n"; then
            print_success "Using existing age key"
        else
            backup_file "$age_key_file" || true
            run_file_op "mkdir" "$(dirname "$age_key_file")" "Create age directory"
            run_command "age-keygen -o '$age_key_file'" "Generate age key"
            print_success "New age key generated"
        fi
    else
        log_info "Generating age encryption key..."
        run_file_op "mkdir" "$(dirname "$age_key_file")" "Create age directory"
        run_command "age-keygen -o '$age_key_file'" "Generate age key"
        print_success "Age key generated"
    fi
    
    # Get keys
    local user_key host_key=""
    if ! is_dry_run; then
        user_key=$(grep "public key:" "$age_key_file" | cut -d: -f2 | tr -d ' ')
        [[ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]] && \
            host_key=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
    else
        user_key="age1dummy..."
        host_key="age1dummy..."
    fi
    
    # Create .sops.yaml
    local sops_content
    sops_content=$(cat <<EOF
# SOPS configuration - Generated $(date)
keys:
  - &user_semyenov $user_key
EOF
)
    [[ -n "$host_key" ]] && sops_content+=$(cat <<EOF

  - &host_nixos $host_key
EOF
)
    sops_content+=$(cat <<'EOF'

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *user_semyenov
EOF
)
    [[ -n "$host_key" ]] && sops_content+=$(cat <<'EOF'
          - *host_nixos
EOF
)

    write_file ".sops.yaml" "$sops_content" "Create .sops.yaml"
    
    print_success "SOPS configuration complete!"
    log_info "You can now encrypt secrets with: sops secrets/v2ray.yaml"
}

# ========================
# V2Ray Config Command
# ========================

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

cmd_v2ray_config() {
    # Check for help first
    if is_help_requested "$@"; then
        cat <<EOF
${COLOR_BLUE}V2Ray Configuration${COLOR_RESET}
Configure V2Ray proxy from VLESS connection string

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") v2ray-config [OPTIONS] VLESS_URL

${COLOR_YELLOW}Options:${COLOR_RESET}
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -n, --dry-run   Show what would be done
    -f, --force     Overwrite existing configuration

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Configure V2Ray from VLESS URL
    $(basename "$0") v2ray-config 'vless://UUID@server:port?...'
    
    # Show what would be configured
    $(basename "$0") v2ray-config -n 'vless://...'
EOF
        return 0
    fi
    
    # Get VLESS URL from arguments
    local vless_url=""
    for arg in "$@"; do
        if [[ "$arg" =~ ^vless:// ]]; then
            vless_url="$arg"
            break
        fi
    done
    
    if [[ -z "$vless_url" ]]; then
        log_error "No VLESS URL provided"
        log_info "Usage: $(basename "$0") v2ray-config 'vless://...'"
        return 1
    fi
    
    print_header "V2Ray Configuration from VLESS URL"
    show_dry_run_warning
    
    # Parse VLESS URL
    local uuid="" server="" port="" public_key="" short_id="" sni="" fingerprint="" spx=""
    
    # Validate URL format
    if [[ ! "$vless_url" =~ ^vless:// ]]; then
        log_error "Invalid VLESS URL format"
        return 1
    fi
    
    # Extract base components using regex
    local regex='vless://([^@]+)@([^:]+):([0-9]+)'
    if [[ "$vless_url" =~ $regex ]]; then
        uuid="${BASH_REMATCH[1]}"
        server="${BASH_REMATCH[2]}"
        port="${BASH_REMATCH[3]}"
    else
        log_error "Failed to parse VLESS URL structure"
        return 1
    fi
    
    # Extract query string
    local query=""
    if [[ "$vless_url" =~ \?([^#]+) ]]; then
        query="${BASH_REMATCH[1]}"
    fi
    
    # Parse query parameters
    if [[ -n "$query" ]]; then
        IFS='&' read -ra params <<< "$query"
        for param in "${params[@]}"; do
            IFS='=' read -r key value <<< "$param"
            case "$key" in
                pbk) public_key="$value" ;;
                sid) short_id="$value" ;;
                sni) sni="$value" ;;
                fp)  fingerprint="$value" ;;
                spx) spx=$(urldecode "$value") ;;
            esac
        done
    fi
    
    # Display parsed configuration
    log_info "Parsed V2Ray configuration:"
    echo "  Server:      $server:$port"
    echo "  UUID:        $uuid"
    echo "  Public Key:  $public_key"
    echo "  Short ID:    $short_id"
    [[ -n "$sni" ]] && echo "  SNI:         $sni"
    [[ -n "$fingerprint" ]] && echo "  Fingerprint: $fingerprint"
    [[ -n "$spx" ]] && echo "  SpiderX:     $spx"
    echo
    
    # Check if secrets file exists
    local secrets_file="secrets/v2ray.yaml"
    if [[ -f "$secrets_file" ]] && [[ "$FORCE" != "true" ]]; then
        log_warn "V2Ray secrets already exist"
        if ! confirm "Overwrite existing configuration?" "n"; then
            return 0
        fi
    fi
    
    # Create secrets YAML content
    local yaml_content="# V2Ray Configuration
# Generated from VLESS URL on $(date)
v2ray:
    server_address: \"$server\"
    server_port: $port
    user_id: \"$uuid\"
    public_key: \"$public_key\"
    short_id: \"${short_id:-}\""
    
    # Write temporary unencrypted file
    local temp_file
    temp_file=$(create_temp_file "v2ray.yaml.XXXXXX")
    echo "$yaml_content" > "$temp_file"
    
    # Encrypt with SOPS
    if command_exists sops; then
        log_info "Encrypting secrets with SOPS..."
        if run_command "sops -e -i '$temp_file'" "Encrypt V2Ray secrets"; then
            # Move to final location
            run_file_op "move" "$temp_file" "$secrets_file" "Save encrypted secrets"
            print_success "V2Ray configuration saved and encrypted"
            
            log_info "To enable V2Ray, add to your configuration:"
            echo "  services.v2ray.enable = true;"
        else
            log_error "Failed to encrypt secrets"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_warn "SOPS not available, saving unencrypted"
        run_file_op "move" "$temp_file" "$secrets_file.plain" "Save plain secrets"
        log_warn "Secrets saved to $secrets_file.plain (NOT ENCRYPTED)"
        log_info "Install SOPS to enable encryption"
    fi
}

# ========================
# Main Execution
# ========================

main() {
    local command=""
    
    # Parse global options and extract command
    local -a args
    mapfile -t args < <(parse_common_options "$@")
    
    # Check if help was returned
    for arg in "${args[@]}"; do
        [[ "$arg" == "help" ]] && { show_main_help; exit 0; }
    done
    
    # Get command from remaining args
    for arg in "${args[@]}"; do
        case "$arg" in
            rebuild|setup|test|update|clean|rollback|sops|v2ray-config|help)
                command="$arg"
                break
                ;;
        esac
    done
    
    # Default command
    [[ -z "$command" ]] && command="rebuild"
    
    # Setup error handling
    setup_error_handling
    
    # Show dry-run warning if applicable
    export DRY_RUN VERBOSE FORCE AUTO_YES
    
    # Execute command with remaining arguments
    case "$command" in
        rebuild)      cmd_rebuild "${args[@]}" ;;
        setup)        cmd_setup "${args[@]}" ;;
        test)         cmd_test "${args[@]}" ;;
        update)       cmd_update "${args[@]}" ;;
        clean)        cmd_clean "${args[@]}" ;;
        rollback)     cmd_rollback "${args[@]}" ;;
        sops)         cmd_sops "${args[@]}" ;;
        v2ray-config) cmd_v2ray_config "${args[@]}" ;;
        help)         show_main_help ;;
        *)
            error_invalid_option "$command"
            show_main_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"