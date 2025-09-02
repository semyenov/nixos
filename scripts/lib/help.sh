#!/usr/bin/env bash
# Help Functions Library
# Provides help text functions for all commands

# Main help
show_main_help() {
    cat <<EOF
${COLOR_BLUE}NixOS Manager v${VERSION:-2.0.0}${COLOR_RESET}
Unified management tool for NixOS configuration

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") [COMMAND] [OPTIONS]

${COLOR_YELLOW}Commands:${COLOR_RESET}
    rebuild      Rebuild NixOS configuration (default)
    setup        Initial system setup wizard
    test         Validate configuration
    update       Update flake inputs
    clean        Clean old generations and optimize store
    rollback     Rollback to previous generation
    sops         Setup SOPS encryption
    v2ray-config Configure V2Ray from VLESS URL
    help         Show this help message

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
    - Configuration lives in: ${FLAKE_PATH:-/etc/nixos}

For command-specific help: $(basename "$0") [COMMAND] --help
EOF
}

# Rebuild command help
show_rebuild_help() {
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
    
    # Dry run
    $(basename "$0") rebuild -n
EOF
}

# Setup command help
show_setup_help() {
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
}

# Test command help
show_test_help() {
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
    performance Check performance optimizations
    shellcheck  Validate shell scripts
    formatting  Check code formatting

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
    
    # Generate JSON report
    $(basename "$0") test --format json > report.json
EOF
}

# Update command help
show_update_help() {
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
    
    # Update and rebuild
    $(basename "$0") update && $(basename "$0") rebuild
EOF
}

# Clean command help
show_clean_help() {
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
    
    # Keep 10 generations
    $(basename "$0") clean -k 10
EOF
}

# Rollback command help
show_rollback_help() {
    cat <<EOF
${COLOR_BLUE}Rollback Command${COLOR_RESET}
Rollback to previous system generation

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") rollback

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Rollback to previous generation
    $(basename "$0") rollback
    
    # View available generations first
    nix-env --list-generations --profile /nix/var/nix/profiles/system
EOF
}

# SOPS command help
show_sops_help() {
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
    
    # Edit existing secrets:
    sops secrets/v2ray.yaml
EOF
}

# Show help for specific command
show_command_help() {
    local command="$1"
    
    case "$command" in
        rebuild)  show_rebuild_help ;;
        setup)    show_setup_help ;;
        test)     show_test_help ;;
        update)   show_update_help ;;
        clean)    show_clean_help ;;
        rollback) show_rollback_help ;;
        sops)     show_sops_help ;;
        help|*)   show_main_help ;;
    esac
}

# Export all help functions
export -f show_main_help show_rebuild_help show_setup_help
export -f show_test_help show_update_help show_clean_help
export -f show_rollback_help show_sops_help show_command_help