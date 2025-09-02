#!/usr/bin/env bash
# Unified NixOS Management Script
# Single entrypoint for all NixOS configuration operations

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"

# Script configuration
readonly SCRIPT_NAME="NixOS Manager"
readonly VERSION="2.0.0"
readonly FLAKE_PATH="${FLAKE_PATH:-$PROJECT_ROOT}"
readonly HOSTNAME="${HOSTNAME:-nixos}"
readonly FLAKE_REF="${FLAKE_PATH}#${HOSTNAME}"

# Global options
DRY_RUN=false
VERBOSE=false
FORCE=false
AUTO_YES=false

# ========================
# Help and Usage
# ========================

show_usage() {
    cat <<EOF
${COLOR_BLUE}$SCRIPT_NAME v$VERSION${COLOR_RESET}
Unified management tool for NixOS configuration

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") [COMMAND] [OPTIONS]

${COLOR_YELLOW}Commands:${COLOR_RESET}
    rebuild     Rebuild NixOS configuration (default)
    setup       Initial system setup wizard
    test        Validate configuration
    update      Update flake inputs
    clean       Clean old generations and optimize store
    rollback    Rollback to previous generation
    sops        Setup SOPS encryption
    help        Show this help message

${COLOR_YELLOW}Common Options:${COLOR_RESET}
    -h, --help      Show help for command
    -v, --verbose   Enable verbose output
    -n, --dry-run   Show what would be done
    -f, --force     Skip confirmations
    -y, --yes       Auto-answer yes to prompts

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Quick rebuild (default command)
    $(basename "$0")
    
    # Setup new system
    $(basename "$0") setup
    
    # Test configuration
    $(basename "$0") test
    
    # Update and rebuild
    $(basename "$0") update && $(basename "$0") rebuild
    
    # Clean system
    $(basename "$0") clean

${COLOR_YELLOW}Quick Tips:${COLOR_RESET}
    - Default command is 'rebuild' when no command specified
    - Git changes are auto-staged before rebuild
    - Use -n for dry-run to preview changes
    - Configuration lives in: $FLAKE_PATH

For command-specific help: $(basename "$0") [COMMAND] --help
EOF
}

# ========================
# Rebuild Command
# ========================

cmd_rebuild() {
    local operation="switch"
    local upgrade=false
    local no_stage=false
    local no_commit=false
    
    # Parse rebuild-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}Rebuild Command${COLOR_RESET}
Rebuild and switch to new NixOS configuration

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") rebuild [OPTIONS] [OPERATION]

${COLOR_YELLOW}Operations:${COLOR_RESET}
    switch      Switch to new configuration (default)
    test        Test configuration without making default
    boot        Update boot configuration only
    dry-build   Build without switching

${COLOR_YELLOW}Options:${COLOR_RESET}
    -u, --upgrade       Update flake inputs before rebuild
    --no-stage          Don't auto-stage git changes
    --no-commit         Don't auto-commit changes
    --show-trace        Show full error trace

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Quick rebuild
    $(basename "$0") rebuild
    
    # Test configuration
    $(basename "$0") rebuild test
    
    # Upgrade and rebuild
    $(basename "$0") rebuild -u
EOF
                return 0
                ;;
            -u|--upgrade) upgrade=true ;;
            --no-stage) no_stage=true ;;
            --no-commit) no_commit=true ;;
            --show-trace) VERBOSE=true ;;
            switch|test|boot|dry-build) operation="$1" ;;
            *) log_error "Unknown rebuild option: $1"; return 1 ;;
        esac
        shift
    done
    
    print_header "NixOS Rebuild: $operation"
    
    # Check git status and auto-stage if needed
    if [[ "$no_stage" != "true" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
        local modified
        modified=$(git status --porcelain | wc -l)
        
        if [[ $modified -gt 0 ]]; then
            log_info "Found $modified modified files"
            if [[ "$DRY_RUN" == "false" ]]; then
                git add -A
                print_success "Changes staged"
                
                if [[ "$no_commit" != "true" ]] && [[ $(git diff --cached | wc -l) -gt 0 ]]; then
                    git commit -m "Auto-commit: Configuration update $(date +%Y-%m-%d)" >/dev/null
                    print_success "Changes committed"
                fi
            else
                log_info "[DRY RUN] Would stage $modified files"
            fi
        fi
    fi
    
    # Update flake if requested
    if [[ "$upgrade" == "true" ]]; then
        log_info "Updating flake inputs..."
        if [[ "$DRY_RUN" == "false" ]]; then
            nix flake update "$FLAKE_PATH"
            git add "$FLAKE_PATH/flake.lock"
            print_success "Flake inputs updated"
        else
            log_info "[DRY RUN] Would update flake inputs"
        fi
    fi
    
    # Check disk space
    local available
    available=$(df /nix/store | tail -1 | awk '{print $4}')
    if [[ $available -lt 5000000 ]]; then
        log_warn "Low disk space in /nix/store"
        if confirm "Run garbage collection?" "y"; then
            cmd_clean
        fi
    fi
    
    # Perform rebuild
    local rebuild_args=("$operation" "--flake" "$FLAKE_REF")
    [[ "$VERBOSE" == "true" ]] && rebuild_args+=("--show-trace")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: sudo nixos-rebuild ${rebuild_args[*]}"
    else
        log_info "Building configuration..."
        if sudo nixos-rebuild "${rebuild_args[@]}"; then
            print_success "Rebuild successful!"
            
            # Show new generation
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
        else
            print_error "Rebuild failed!"
            return 1
        fi
    fi
}

# ========================
# Setup Command
# ========================

cmd_setup() {
    local skip_hardware=false
    local skip_sops=false
    local skip_test=false
    local skip_build=false
    
    # Parse setup-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}Setup Command${COLOR_RESET}
Initial NixOS configuration setup wizard

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") setup [OPTIONS]

${COLOR_YELLOW}Options:${COLOR_RESET}
    --skip-hardware     Skip hardware configuration
    --skip-sops         Skip SOPS setup
    --skip-test         Skip configuration testing
    --skip-build        Skip configuration build
    -q, --quick         Quick setup (auto-yes to all)

${COLOR_YELLOW}Setup Steps:${COLOR_RESET}
    1. Check prerequisites
    2. Generate hardware configuration
    3. Setup SOPS encryption
    4. Test configuration
    5. Build configuration
    6. Apply configuration (optional)

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Full interactive setup
    $(basename "$0") setup
    
    # Quick setup (auto-yes)
    $(basename "$0") setup -q
    
    # Only SOPS setup
    $(basename "$0") setup --skip-hardware --skip-test --skip-build
EOF
                return 0
                ;;
            --skip-hardware) skip_hardware=true ;;
            --skip-sops) skip_sops=true ;;
            --skip-test) skip_test=true ;;
            --skip-build) skip_build=true ;;
            -q|--quick) AUTO_YES=true ;;
            *) log_error "Unknown setup option: $1"; return 1 ;;
        esac
        shift
    done
    
    print_header "NixOS Setup Wizard"
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    check_requirements git age ssh-to-age sops nix || return 1
    
    if [[ ! -f "flake.nix" ]]; then
        log_error "flake.nix not found"
        log_info "Please ensure you're in the NixOS configuration directory"
        return 1
    fi
    print_success "Prerequisites satisfied"
    
    # Generate hardware configuration
    if [[ "$skip_hardware" != "true" ]]; then
        local hw_config="hosts/nixos/hardware-configuration.nix"
        
        if [[ -f "$hw_config" ]]; then
            log_warn "Hardware configuration exists"
            if confirm "Regenerate hardware configuration?" "n"; then
                if [[ "$DRY_RUN" == "false" ]]; then
                    sudo nixos-generate-config --dir "$(dirname "$hw_config")"
                    git add "$hw_config" 2>/dev/null || true
                fi
            fi
        else
            log_info "Generating hardware configuration..."
            if [[ "$DRY_RUN" == "false" ]]; then
                mkdir -p "$(dirname "$hw_config")"
                sudo nixos-generate-config --dir "$(dirname "$hw_config")"
                git add "$hw_config" 2>/dev/null || true
            fi
        fi
        print_success "Hardware configuration ready"
    fi
    
    # Setup SOPS
    if [[ "$skip_sops" != "true" ]]; then
        cmd_sops
    fi
    
    # Test configuration
    if [[ "$skip_test" != "true" ]]; then
        log_info "Testing configuration..."
        if [[ "$DRY_RUN" == "false" ]]; then
            if nix flake check --no-build 2>/dev/null; then
                print_success "Configuration valid"
            else
                log_error "Configuration validation failed"
                return 1
            fi
        fi
    fi
    
    # Build configuration
    if [[ "$skip_build" != "true" ]]; then
        if confirm "Build configuration?" "y"; then
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo nixos-rebuild build --flake "$FLAKE_REF"
            fi
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
    local tests_to_run=()
    local parallel=true
    local fail_fast=false
    local format="terminal"
    
    # Parse test-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}Test Command${COLOR_RESET}
Validate NixOS configuration

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") test [OPTIONS] [TESTS...]

${COLOR_YELLOW}Available Tests:${COLOR_RESET}
    all         Run all tests (default)
    syntax      Check Nix syntax
    flake       Validate flake structure
    build       Test configuration build
    modules     Check module imports
    secrets     Validate secrets configuration
    hardware    Check hardware configuration
    security    Check security settings

${COLOR_YELLOW}Options:${COLOR_RESET}
    -s, --sequential    Run tests sequentially
    -f, --fail-fast     Stop on first failure
    --format FORMAT     Output format (terminal, json, xml)

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Run all tests
    $(basename "$0") test
    
    # Run specific tests
    $(basename "$0") test syntax flake
    
    # Quick validation with fail-fast
    $(basename "$0") test -f
EOF
                return 0
                ;;
            -s|--sequential) parallel=false ;;
            -f|--fail-fast) fail_fast=true; parallel=false ;;
            --format) shift; format="$1" ;;
            all) tests_to_run=(syntax flake build modules secrets hardware security) ;;
            syntax|flake|build|modules|secrets|hardware|security)
                tests_to_run+=("$1") ;;
            *) 
                # Unknown option, might be a test name
                if [[ "$1" =~ ^- ]]; then
                    log_error "Unknown option: $1"
                    return 1
                else
                    log_error "Unknown test: $1"
                    return 1
                fi
                ;;
        esac
        shift
    done
    
    # Default to all tests
    [[ ${#tests_to_run[@]} -eq 0 ]] && tests_to_run=(syntax flake build modules secrets hardware security)
    
    print_header "Configuration Validation"
    
    local passed=0
    local failed=0
    local skipped=0
    
    # Test functions
    test_syntax() {
        find . -name "*.nix" -type f -exec nix-instantiate --parse {} \; >/dev/null 2>&1
    }
    
    test_flake() {
        [[ -f "flake.nix" ]] && nix flake check --no-build 2>/dev/null
    }
    
    test_build() {
        command_exists nixos-rebuild && sudo nixos-rebuild dry-build --flake "$FLAKE_REF" 2>/dev/null
    }
    
    test_modules() {
        nix-instantiate --eval -E "(import ./flake.nix).nixosConfigurations.nixos.config" >/dev/null 2>&1
    }
    
    test_secrets() {
        [[ -f ".sops.yaml" ]] && grep -q "age1" .sops.yaml
    }
    
    test_hardware() {
        local hw_config="hosts/nixos/hardware-configuration.nix"
        [[ -f "$hw_config" ]] || hw_config="hardware-configuration.nix"
        [[ -f "$hw_config" ]] && nix-instantiate --parse "$hw_config" >/dev/null 2>&1
    }
    
    test_security() {
        ! grep -r "password\|secret\|token\|key" --include="*.nix" | \
            grep -v "sops\|age\|ssh\|gnupg\|passwordAuthentication" | \
            grep "=" >/dev/null 2>&1
    }
    
    # Run tests
    for test in "${tests_to_run[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run test: $test"
        else
            if test_"$test" 2>/dev/null; then
                print_success "$test"
                ((passed++))
            else
                print_error "$test"
                ((failed++))
                [[ "$fail_fast" == "true" ]] && break
            fi
        fi
    done
    
    # Summary
    echo
    if [[ "$format" == "terminal" ]]; then
        log_info "Tests passed: $passed"
        [[ $failed -gt 0 ]] && log_error "Tests failed: $failed"
        [[ $skipped -gt 0 ]] && log_warn "Tests skipped: $skipped"
        
        if [[ $failed -gt 0 ]]; then
            print_error "Configuration has errors!"
            return 1
        else
            print_success "Configuration valid!"
        fi
    elif [[ "$format" == "json" ]]; then
        echo "{\"passed\":$passed,\"failed\":$failed,\"skipped\":$skipped}"
    fi
}

# ========================
# Update Command
# ========================

cmd_update() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}Update Command${COLOR_RESET}
Update flake inputs to latest versions

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") update [INPUT]

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Update all inputs
    $(basename "$0") update
    
    # Update specific input
    $(basename "$0") update nixpkgs
EOF
                return 0
                ;;
            *) break ;;
        esac
        shift
    done
    
    print_header "Update Flake Inputs"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update flake inputs"
    else
        if [[ -n "$1" ]]; then
            log_info "Updating input: $1"
            nix flake lock --update-input "$1"
        else
            log_info "Updating all inputs..."
            nix flake update
        fi
        
        git add flake.lock
        print_success "Flake inputs updated"
        
        log_info "Current inputs:"
        nix flake metadata --json | jq -r '.locks.nodes.root.inputs | to_entries[] | "  - \(.key)"'
    fi
}

# ========================
# Clean Command
# ========================

cmd_clean() {
    local keep_generations=5
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}Clean Command${COLOR_RESET}
Clean old generations and optimize store

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") clean [OPTIONS]

${COLOR_YELLOW}Options:${COLOR_RESET}
    -k, --keep NUM      Keep NUM most recent generations (default: 5)
    -a, --all           Delete all old generations

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Clean, keeping 5 recent generations
    $(basename "$0") clean
    
    # Delete all old generations
    $(basename "$0") clean -a
EOF
                return 0
                ;;
            -k|--keep) shift; keep_generations="$1" ;;
            -a|--all) keep_generations=0 ;;
            *) log_error "Unknown clean option: $1"; return 1 ;;
        esac
        shift
    done
    
    print_header "System Cleanup"
    
    # Show current disk usage
    log_info "Current /nix/store usage:"
    df -h /nix/store | tail -1
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would clean old generations and optimize store"
    else
        # Delete old generations
        if [[ $keep_generations -eq 0 ]]; then
            log_info "Deleting all old generations..."
            sudo nix-collect-garbage -d
        else
            log_info "Keeping $keep_generations most recent generations..."
            sudo nix-env --delete-generations +$keep_generations --profile /nix/var/nix/profiles/system
            sudo nix-collect-garbage
        fi
        
        # Optimize store
        log_info "Optimizing Nix store..."
        nix-store --optimise
        
        # Show new disk usage
        log_info "New /nix/store usage:"
        df -h /nix/store | tail -1
        
        print_success "Cleanup complete!"
    fi
}

# ========================
# Rollback Command
# ========================

cmd_rollback() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}Rollback Command${COLOR_RESET}
Rollback to previous system generation

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") rollback

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Rollback to previous generation
    $(basename "$0") rollback
EOF
                return 0
                ;;
            *) log_error "Unknown rollback option: $1"; return 1 ;;
        esac
        shift
    done
    
    print_header "System Rollback"
    
    # Show current generation
    local current_gen
    current_gen=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep current | awk '{print $1}')
    log_info "Current generation: $current_gen"
    
    # Show available generations
    log_info "Available generations:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -5
    
    if confirm "Rollback to previous generation?" "y"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would rollback to previous generation"
        else
            sudo nixos-rebuild switch --rollback
            print_success "Rollback complete!"
        fi
    fi
}

# ========================
# SOPS Command
# ========================

cmd_sops() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
${COLOR_BLUE}SOPS Command${COLOR_RESET}
Setup SOPS encryption for secrets management

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") sops

${COLOR_YELLOW}Setup Steps:${COLOR_RESET}
    1. Generate age encryption key
    2. Extract host SSH key
    3. Create .sops.yaml configuration
    4. Ready to encrypt secrets

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Setup SOPS
    $(basename "$0") sops
    
    # After setup, encrypt secrets with:
    sops secrets/v2ray.yaml
EOF
                return 0
                ;;
            *) log_error "Unknown sops option: $1"; return 1 ;;
        esac
        shift
    done
    
    print_header "SOPS Encryption Setup"
    
    local age_key_file="$HOME/.config/sops/age/keys.txt"
    
    # Generate age key if needed
    if [[ -f "$age_key_file" ]]; then
        log_warn "Age key already exists"
        if ! confirm "Generate new age key?" "n"; then
            print_success "Using existing age key"
        else
            if [[ "$DRY_RUN" == "false" ]]; then
                backup_file "$age_key_file" || true
                mkdir -p "$(dirname "$age_key_file")"
                age-keygen -o "$age_key_file"
            fi
            print_success "New age key generated"
        fi
    else
        log_info "Generating age encryption key..."
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$age_key_file")"
            age-keygen -o "$age_key_file"
        fi
        print_success "Age key generated"
    fi
    
    # Get keys
    local user_key host_key=""
    if [[ "$DRY_RUN" == "false" ]]; then
        user_key=$(grep "public key:" "$age_key_file" | cut -d: -f2 | tr -d ' ')
        [[ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]] && \
            host_key=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
    else
        user_key="age1dummy..."
        host_key="age1dummy..."
    fi
    
    # Create .sops.yaml
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > .sops.yaml <<EOF
# SOPS configuration - Generated $(date)
keys:
  - &user_semyenov $user_key
EOF
        [[ -n "$host_key" ]] && cat >> .sops.yaml <<EOF
  - &host_nixos $host_key
EOF
        cat >> .sops.yaml <<'EOF'

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *user_semyenov
EOF
        [[ -n "$host_key" ]] && cat >> .sops.yaml <<'EOF'
          - *host_nixos
EOF
    else
        log_info "[DRY RUN] Would create .sops.yaml"
    fi
    
    print_success "SOPS configuration complete!"
    log_info "You can now encrypt secrets with: sops secrets/v2ray.yaml"
}

# ========================
# Main Execution
# ========================

main() {
    local command=""
    
    # Parse global options and command
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            rebuild|setup|test|update|clean|rollback|sops|help)
                command="$1"
                shift
                break
                ;;
            *)
                # Default to rebuild if no recognized command
                command="rebuild"
                break
                ;;
        esac
    done
    
    # Default command
    [[ -z "$command" ]] && command="rebuild"
    
    # Setup error handling
    setup_error_handling
    
    # Show dry-run warning
    [[ "$DRY_RUN" == "true" ]] && print_warning "DRY RUN MODE - No changes will be made"
    
    # Execute command
    case "$command" in
        rebuild)  cmd_rebuild "$@" ;;
        setup)    cmd_setup "$@" ;;
        test)     cmd_test "$@" ;;
        update)   cmd_update "$@" ;;
        clean)    cmd_clean "$@" ;;
        rollback) cmd_rollback "$@" ;;
        sops)     cmd_sops "$@" ;;
        help)     show_usage ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"