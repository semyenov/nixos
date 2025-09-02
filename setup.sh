#!/usr/bin/env bash
# NixOS Configuration Setup Script
# This script automates the initial setup of the NixOS system configuration
# Updated to include all new modules and improvements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        print_warning "It will request sudo privileges when needed"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check for required commands
    for cmd in git age ssh-to-age sops nix; do
        if ! command -v $cmd &> /dev/null; then
            missing_tools+=($cmd)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_warning "Installing missing tools..."
        nix-shell -p age sops ssh-to-age --run "echo 'Tools available in shell'"
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        if confirm "Initialize git repository?"; then
            git init
            git add .
            git commit -m "Initial commit"
            print_success "Git repository initialized"
        else
            print_error "Git repository required for flakes"
            exit 1
        fi
    else
        print_success "Git repository detected"
    fi
    
    # Check if flake.nix exists
    if [ ! -f "flake.nix" ]; then
        print_error "flake.nix not found"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Generate hardware configuration
generate_hardware_config() {
    print_header "Hardware Configuration"
    
    local hw_config="hosts/nixos/hardware-configuration.nix"
    
    if [ -f "$hw_config" ]; then
        print_warning "Hardware configuration already exists at $hw_config"
        if confirm "Regenerate hardware configuration?"; then
            print_warning "Backing up existing configuration"
            cp "$hw_config" "$hw_config.backup.$(date +%Y%m%d_%H%M%S)"
            mkdir -p hosts/nixos
            sudo nixos-generate-config --dir hosts/nixos/
            print_success "Hardware configuration regenerated"
            
            # Add to git
            git add "$hw_config"
            print_success "Added hardware configuration to git"
        else
            print_success "Using existing hardware configuration"
        fi
    else
        print_warning "Generating hardware configuration..."
        mkdir -p hosts/nixos
        sudo nixos-generate-config --dir hosts/nixos/
        print_success "Hardware configuration generated at $hw_config"
        
        # Add to git
        git add "$hw_config"
        print_success "Added hardware configuration to git"
    fi
}

# Setup SOPS encryption
setup_sops() {
    print_header "SOPS Encryption Setup"
    
    # Use the dedicated SOPS setup script if available
    if [ -f "scripts/setup-sops.sh" ]; then
        print_info "Using dedicated SOPS setup script"
        bash scripts/setup-sops.sh
        print_success "SOPS configuration completed"
        return
    fi
    
    local age_key_dir="$HOME/.config/sops/age"
    local age_key_file="$age_key_dir/keys.txt"
    
    # Check if age key already exists
    if [ -f "$age_key_file" ]; then
        print_warning "Age key already exists at $age_key_file"
        if confirm "Generate new age key? (This will backup the existing one)"; then
            mv "$age_key_file" "$age_key_file.backup.$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$age_key_dir"
            age-keygen -o "$age_key_file"
            print_success "New age key generated"
        else
            print_success "Using existing age key"
        fi
    else
        print_warning "Generating age encryption key..."
        mkdir -p "$age_key_dir"
        age-keygen -o "$age_key_file"
        print_success "Age key generated at $age_key_file"
    fi
    
    # Extract user public key
    USER_PUBLIC_KEY=$(grep "public key:" "$age_key_file" | cut -d: -f2 | tr -d ' ')
    echo -e "User public key: ${GREEN}$USER_PUBLIC_KEY${NC}"
    
    # Get host SSH key
    HOST_PUBLIC_KEY=""
    if [ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]; then
        HOST_PUBLIC_KEY=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
        echo -e "Host public key: ${GREEN}$HOST_PUBLIC_KEY${NC}"
    else
        print_warning "Host SSH key not found - will need to be added manually"
    fi
    
    # Update .sops.yaml if it doesn't have keys configured
    if [ -f ".sops.yaml" ] && grep -q "age1" .sops.yaml; then
        print_success ".sops.yaml already configured with age keys"
    else
        print_warning "Updating .sops.yaml with age keys..."
        cat > .sops.yaml <<EOF
# SOPS configuration for secrets management
# Auto-generated on $(date)

keys:
  - &user_semyenov $USER_PUBLIC_KEY
EOF

        if [ -n "$HOST_PUBLIC_KEY" ]; then
            cat >> .sops.yaml <<EOF
  - &host_nixos $HOST_PUBLIC_KEY
EOF
        fi

        cat >> .sops.yaml <<EOF

creation_rules:
  # Default rule for all secrets
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *user_semyenov
EOF

        if [ -n "$HOST_PUBLIC_KEY" ]; then
            cat >> .sops.yaml <<EOF
          - *host_nixos
EOF
        fi

        cat >> .sops.yaml <<EOF
  
  # User-specific secrets
  - path_regex: secrets/users/[^/]+\.yaml$
    key_groups:
      - age:
          - *user_semyenov
EOF
        print_success "Created .sops.yaml with proper keys"
    fi
}

# Setup V2Ray secrets
setup_v2ray_secrets() {
    print_header "V2Ray Secrets Configuration"
    
    if [ ! -f "secrets/v2ray.yaml.example" ]; then
        print_warning "V2Ray example configuration not found, skipping"
        return
    fi
    
    if [ -f "secrets/v2ray.yaml" ]; then
        print_warning "V2Ray secrets already exist"
        if confirm "Reconfigure V2Ray secrets?"; then
            print_warning "Backing up existing secrets..."
            cp "secrets/v2ray.yaml" "secrets/v2ray.yaml.backup.$(date +%Y%m%d_%H%M%S)"
        else
            print_success "Using existing V2Ray secrets"
            return
        fi
    fi
    
    if confirm "Setup V2Ray proxy configuration?"; then
        # Check if configure-v2ray.sh exists
        if [ -f "configure-v2ray.sh" ]; then
            print_info "V2Ray configuration helper available"
            echo "You can configure V2Ray using:"
            echo "  ${YELLOW}./configure-v2ray.sh 'vless://...'${NC}"
            echo
            if confirm "Do you have a VLESS connection string to configure now?"; then
                read -p "Enter VLESS URL: " vless_url
                ./configure-v2ray.sh "$vless_url"
            else
                print_info "You can configure V2Ray later using ./configure-v2ray.sh"
            fi
        else
            print_warning "Copying V2Ray example configuration..."
            cp "secrets/v2ray.yaml.example" "secrets/v2ray.yaml"
            
            print_warning "Opening V2Ray secrets for editing..."
            print_warning "Please configure your V2Ray settings"
            sleep 2
            
            if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
                sops "secrets/v2ray.yaml"
                print_success "V2Ray secrets configured"
            else
                print_warning "SOPS not configured, edit secrets/v2ray.yaml manually"
            fi
        fi
        
        print_info "Remember to enable V2Ray in your host configuration:"
        echo "  ${YELLOW}services.v2ray.enable = true;${NC}"
    else
        print_warning "Skipping V2Ray configuration"
    fi
}

# Configure optional services
configure_services() {
    print_header "Optional Services Configuration"
    
    local services_to_enable=()
    
    echo "The following optional services are available:"
    echo
    
    if confirm "Enable automatic backups (BorgBackup)?"; then
        services_to_enable+=("services.simpleBackup.enable = true;")
        print_success "Backup service will be enabled"
    fi
    
    if confirm "Enable system monitoring (Prometheus/Grafana)?"; then
        services_to_enable+=("services.monitoring.enable = true;")
        print_success "Monitoring service will be enabled"
    fi
    
    if confirm "Enable hardware auto-detection and optimization?"; then
        services_to_enable+=("hardware.autoDetect.enable = true;")
        print_success "Hardware auto-detection will be enabled"
    fi
    
    if [ ${#services_to_enable[@]} -gt 0 ]; then
        print_info "Add these lines to hosts/nixos/configuration.nix:"
        for service in "${services_to_enable[@]}"; do
            echo "  ${YELLOW}$service${NC}"
        done
        echo
        
        if confirm "Open configuration file in editor now?"; then
            ${EDITOR:-nano} hosts/nixos/configuration.nix
        fi
    fi
}

# Test configuration
test_configuration() {
    print_header "Testing Configuration"
    
    # Add all new files to git (required for flakes)
    print_info "Adding new files to git..."
    git add -A
    
    # Run validation script if available
    if [ -f "test-config.sh" ]; then
        print_info "Running configuration validation..."
        if ./test-config.sh; then
            print_success "Configuration validation passed"
        else
            print_warning "Configuration has some issues, check output above"
        fi
    fi
    
    print_warning "Running flake check..."
    if nix flake check --no-build 2>&1 | tee /tmp/nix-flake-check.log; then
        print_success "Flake check passed"
    else
        print_error "Flake check failed. See /tmp/nix-flake-check.log for details"
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi
    
    print_warning "Building configuration (dry-run)..."
    if sudo nixos-rebuild dry-build --flake .#nixos 2>&1 | tee /tmp/nixos-rebuild-dry.log; then
        print_success "Configuration builds successfully"
    else
        print_error "Configuration build failed. See /tmp/nixos-rebuild-dry.log for details"
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi
}

# Apply configuration
apply_configuration() {
    print_header "Apply Configuration"
    
    echo -e "${YELLOW}Ready to apply the NixOS configuration${NC}"
    echo "This will:"
    echo "  1. Build the new configuration"
    echo "  2. Switch to it immediately"
    echo "  3. Update your system packages"
    echo
    
    if confirm "Test configuration first (recommended)?"; then
        print_warning "Testing configuration..."
        if sudo nixos-rebuild test --flake .#nixos; then
            print_success "Test successful!"
            
            if confirm "Apply configuration permanently?"; then
                if sudo nixos-rebuild switch --flake .#nixos; then
                    print_success "Configuration applied successfully!"
                else
                    print_error "Failed to apply configuration"
                    exit 1
                fi
            fi
        else
            print_error "Test failed"
            print_warning "Fix the errors and try again"
            exit 1
        fi
    elif confirm "Apply configuration now?"; then
        print_warning "Building and switching to new configuration..."
        if sudo nixos-rebuild switch --flake .#nixos; then
            print_success "Configuration applied successfully!"
        else
            print_error "Failed to apply configuration"
            exit 1
        fi
    else
        print_warning "Configuration not applied"
        print_info "You can apply it manually with:"
        echo "  ${YELLOW}sudo nixos-rebuild switch --flake .#nixos${NC}"
    fi
}

# Post-setup information
show_post_setup() {
    print_header "Post-Setup Information"
    
    echo "Your NixOS configuration is ready! Here are some useful commands:"
    echo
    echo "${CYAN}System Management:${NC}"
    echo "  ${YELLOW}rebuild${NC}     - Rebuild and switch configuration"
    echo "  ${YELLOW}update${NC}      - Update flake inputs"
    echo "  ${YELLOW}clean${NC}       - Clean old generations"
    echo
    echo "${CYAN}Development Shells:${NC}"
    echo "  ${YELLOW}nix develop .#typescript${NC}  - TypeScript/JavaScript"
    echo "  ${YELLOW}nix develop .#python${NC}      - Python"
    echo "  ${YELLOW}nix develop .#rust${NC}        - Rust"
    echo "  ${YELLOW}nix develop .#go${NC}          - Go"
    echo "  ${YELLOW}nix develop .#devops${NC}      - DevOps tools"
    echo
    echo "${CYAN}Configuration Testing:${NC}"
    echo "  ${YELLOW}./test-config.sh${NC}          - Run validation tests"
    echo "  ${YELLOW}nix flake check${NC}           - Check flake validity"
    echo
    echo "${CYAN}V2Ray Proxy (if configured):${NC}"
    echo "  SOCKS5: ${YELLOW}127.0.0.1:1080${NC}"
    echo "  HTTP:   ${YELLOW}127.0.0.1:8118${NC}"
    echo
    echo "${CYAN}Documentation:${NC}"
    echo "  See ${YELLOW}CLAUDE.md${NC} for detailed usage instructions"
    echo
    print_success "Setup complete!"
}

# Quick setup option
quick_setup() {
    print_header "Quick Setup Mode"
    print_warning "This will run all setup steps automatically"
    
    if ! confirm "Continue with quick setup?"; then
        return 1
    fi
    
    generate_hardware_config
    setup_sops
    setup_v2ray_secrets
    configure_services
    test_configuration
    apply_configuration
    show_post_setup
}

# Interactive menu
interactive_menu() {
    while true; do
        print_header "NixOS Configuration Setup Menu"
        echo "1) Quick setup (run all steps)"
        echo "2) Generate hardware configuration"
        echo "3) Setup SOPS encryption"
        echo "4) Configure V2Ray secrets"
        echo "5) Configure optional services"
        echo "6) Test configuration"
        echo "7) Apply configuration"
        echo "8) Show post-setup information"
        echo "9) Exit"
        echo
        read -p "Select an option [1-9]: " choice
        
        case $choice in
            1) quick_setup ;;
            2) generate_hardware_config ;;
            3) setup_sops ;;
            4) setup_v2ray_secrets ;;
            5) configure_services ;;
            6) test_configuration ;;
            7) apply_configuration ;;
            8) show_post_setup ;;
            9) 
                print_success "Exiting setup"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Main execution
main() {
    print_header "NixOS Configuration Setup"
    echo "This script will help you set up your NixOS configuration"
    echo "Repository: $(pwd)"
    echo "Version: Enhanced with monitoring, backups, and hardware optimization"
    echo
    
    check_root
    check_prerequisites
    
    # Check for command line arguments
    if [ $# -eq 0 ]; then
        interactive_menu
    else
        case "$1" in
            quick|--quick|-q)
                quick_setup
                ;;
            hardware|--hardware|-h)
                generate_hardware_config
                ;;
            sops|--sops|-s)
                setup_sops
                ;;
            v2ray|--v2ray|-v)
                setup_v2ray_secrets
                ;;
            services|--services)
                configure_services
                ;;
            test|--test|-t)
                test_configuration
                ;;
            apply|--apply|-a)
                apply_configuration
                ;;
            info|--info|-i)
                show_post_setup
                ;;
            help|--help|-?)
                echo "Usage: $0 [option]"
                echo
                echo "Options:"
                echo "  quick, --quick, -q        Run all setup steps"
                echo "  hardware, --hardware, -h  Generate hardware configuration"
                echo "  sops, --sops, -s         Setup SOPS encryption"
                echo "  v2ray, --v2ray, -v       Configure V2Ray secrets"
                echo "  services, --services      Configure optional services"
                echo "  test, --test, -t         Test configuration"
                echo "  apply, --apply, -a       Apply configuration"
                echo "  info, --info, -i         Show post-setup information"
                echo "  help, --help, -?         Show this help message"
                echo
                echo "No arguments: Interactive menu"
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run '$0 help' for usage information"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"