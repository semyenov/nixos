#!/usr/bin/env bash
# V2Ray Configuration Helper
# Configures V2Ray proxy from VLESS connection string

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"

# Script configuration
readonly SCRIPT_NAME="V2Ray Configuration"
readonly VERSION="2.0.0"
readonly SECRETS_FILE="secrets/v2ray.yaml"

# V2Ray configuration variables
V2RAY_UUID=""
V2RAY_SERVER=""
V2RAY_PORT=""
V2RAY_PUBLIC_KEY=""
V2RAY_SHORT_ID=""
V2RAY_SNI=""
V2RAY_FINGERPRINT=""
V2RAY_SPX=""

# Global options
DRY_RUN=false
VERBOSE=false
FORCE=false

# ========================
# Help and Usage
# ========================

show_usage() {
    cat <<EOF
${COLOR_BLUE}$SCRIPT_NAME v$VERSION${COLOR_RESET}
Configure V2Ray proxy from VLESS connection string

${COLOR_YELLOW}Usage:${COLOR_RESET}
    $(basename "$0") [OPTIONS] VLESS_URL

${COLOR_YELLOW}Options:${COLOR_RESET}
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -n, --dry-run   Show what would be done
    -f, --force     Overwrite existing configuration

${COLOR_YELLOW}Examples:${COLOR_RESET}
    # Configure V2Ray from VLESS URL
    $(basename "$0") 'vless://UUID@server:port?...'
    
    # Dry run to preview configuration
    $(basename "$0") -n 'vless://...'
    
    # Force overwrite existing config
    $(basename "$0") -f 'vless://...'

${COLOR_YELLOW}Configuration Steps:${COLOR_RESET}
    1. Parse VLESS connection string
    2. Extract server details and keys
    3. Create secrets file (secrets/v2ray.yaml)
    4. Encrypt with SOPS if available
    5. Ready to enable V2Ray service

${COLOR_YELLOW}After Configuration:${COLOR_RESET}
    1. Enable V2Ray in your NixOS configuration:
       services.v2ray.enable = true;
    
    2. Rebuild system:
       ./nix.sh rebuild
    
    3. Check service status:
       systemctl status v2ray

${COLOR_YELLOW}Proxy Endpoints:${COLOR_RESET}
    SOCKS5: 127.0.0.1:1080
    HTTP:   127.0.0.1:8118
EOF
}

# ========================
# URL Parsing Functions
# ========================

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

parse_vless_url() {
    local url="$1"
    
    log_debug "Parsing VLESS URL..."
    
    # Validate URL format
    if [[ ! "$url" =~ ^vless:// ]]; then
        log_error "Invalid VLESS URL format"
        log_info "URL must start with 'vless://'"
        return 1
    fi
    
    # Extract base components using regex
    local regex='vless://([^@]+)@([^:]+):([0-9]+)'
    if [[ "$url" =~ $regex ]]; then
        V2RAY_UUID="${BASH_REMATCH[1]}"
        V2RAY_SERVER="${BASH_REMATCH[2]}"
        V2RAY_PORT="${BASH_REMATCH[3]}"
    else
        log_error "Failed to parse VLESS URL structure"
        return 1
    fi
    
    # Extract query string
    local query=""
    if [[ "$url" =~ \?([^#]+) ]]; then
        query="${BASH_REMATCH[1]}"
    fi
    
    # Parse query parameters
    if [[ -n "$query" ]]; then
        IFS='&' read -ra params <<< "$query"
        for param in "${params[@]}"; do
            IFS='=' read -r key value <<< "$param"
            case "$key" in
                pbk) V2RAY_PUBLIC_KEY="$value" ;;
                sid) V2RAY_SHORT_ID="$value" ;;
                sni) V2RAY_SNI="$value" ;;
                fp)  V2RAY_FINGERPRINT="$value" ;;
                spx) V2RAY_SPX=$(urldecode "$value") ;;
            esac
        done
    fi
    
    # Display parsed configuration
    if [[ "$VERBOSE" == "true" ]]; then
        echo
        log_info "Parsed configuration:"
        echo "  UUID:        $V2RAY_UUID"
        echo "  Server:      $V2RAY_SERVER"
        echo "  Port:        $V2RAY_PORT"
        echo "  Public Key:  $V2RAY_PUBLIC_KEY"
        echo "  Short ID:    $V2RAY_SHORT_ID"
        echo "  SNI:         $V2RAY_SNI"
        echo "  Fingerprint: $V2RAY_FINGERPRINT"
        echo "  SpiderX:     $V2RAY_SPX"
        echo
    fi
    
    return 0
}

# ========================
# Configuration Functions
# ========================

check_prerequisites() {
    log_debug "Checking prerequisites..."
    
    # Check for required commands
    local required_commands=(age sops ssh-to-age)
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_warn "Missing optional commands: ${missing_commands[*]}"
        log_info "SOPS encryption will be skipped"
        return 1
    fi
    
    return 0
}

check_sops_setup() {
    log_debug "Checking SOPS configuration..."
    
    # Check age key
    local age_key_file="$HOME/.config/sops/age/keys.txt"
    if [[ ! -f "$age_key_file" ]]; then
        log_warn "SOPS age key not found"
        log_info "Run './nix.sh sops' to setup encryption"
        return 1
    fi
    
    # Check .sops.yaml
    if [[ ! -f ".sops.yaml" ]]; then
        log_warn ".sops.yaml not found"
        log_info "Run './nix.sh sops' to setup encryption"
        return 1
    fi
    
    # Check if keys are properly configured
    if ! grep -q "age1" .sops.yaml 2>/dev/null; then
        log_warn "No age keys found in .sops.yaml"
        return 1
    fi
    
    # Check for commented keys (incomplete setup)
    if grep -q "# - \*user_semyenov" .sops.yaml 2>/dev/null; then
        log_warn "SOPS keys are commented out in .sops.yaml"
        log_info "Please uncomment the keys in .sops.yaml"
        return 1
    fi
    
    log_debug "SOPS is properly configured"
    return 0
}

create_secrets_file() {
    log_info "Creating V2Ray secrets file..."
    
    # Check if secrets directory exists
    if [[ ! -d "secrets" ]]; then
        log_debug "Creating secrets directory..."
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p secrets
        fi
    fi
    
    # Check for existing file
    if [[ -f "$SECRETS_FILE" ]] && [[ "$FORCE" != "true" ]]; then
        log_error "Secrets file already exists: $SECRETS_FILE"
        log_info "Use -f/--force to overwrite"
        return 1
    fi
    
    # Create secrets file content
    local secrets_content
    secrets_content=$(cat <<EOF
# V2Ray configuration secrets
# Generated from VLESS connection string
# Date: $(date -Iseconds)

v2ray:
  server_address: "$V2RAY_SERVER"
  server_port: $V2RAY_PORT
  user_id: "$V2RAY_UUID"
  public_key: "$V2RAY_PUBLIC_KEY"
  short_id: "$V2RAY_SHORT_ID"
EOF
)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create $SECRETS_FILE with:"
        echo "$secrets_content" | sed 's/^/  /'
    else
        echo "$secrets_content" > "$SECRETS_FILE"
        print_success "Created $SECRETS_FILE"
    fi
    
    return 0
}

encrypt_secrets() {
    log_info "Encrypting secrets with SOPS..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would encrypt $SECRETS_FILE"
        return 0
    fi
    
    if sops -e -i "$SECRETS_FILE" 2>/dev/null; then
        print_success "Secrets encrypted successfully"
        return 0
    else
        log_error "Failed to encrypt secrets"
        log_info "The unencrypted file is saved at: $SECRETS_FILE"
        log_info "You can manually encrypt it with: sops -e -i $SECRETS_FILE"
        return 1
    fi
}

show_next_steps() {
    echo
    print_header "Next Steps"
    
    echo "1. Enable V2Ray in your NixOS configuration:"
    echo "   Edit hosts/nixos/configuration.nix and add:"
    echo -e "   ${COLOR_YELLOW}services.v2ray.enable = true;${COLOR_RESET}"
    echo
    
    echo "2. Rebuild your system:"
    echo -e "   ${COLOR_YELLOW}./nix.sh rebuild${COLOR_RESET}"
    echo
    
    echo "3. Verify V2Ray is running:"
    echo -e "   ${COLOR_YELLOW}systemctl status v2ray${COLOR_RESET}"
    echo
    
    echo "4. Configure applications to use the proxy:"
    echo -e "   SOCKS5 proxy: ${COLOR_YELLOW}127.0.0.1:1080${COLOR_RESET}"
    echo -e "   HTTP proxy:   ${COLOR_YELLOW}127.0.0.1:8118${COLOR_RESET}"
    echo
    
    echo "5. Test the connection:"
    echo -e "   ${COLOR_YELLOW}curl -x socks5://127.0.0.1:1080 https://ipinfo.io${COLOR_RESET}"
}

# ========================
# Main Execution
# ========================

main() {
    local vless_url=""
    
    # Parse command line options
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
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                vless_url="$1"
                shift
                ;;
        esac
    done
    
    # Check if URL provided
    if [[ -z "$vless_url" ]]; then
        log_error "No VLESS URL provided"
        echo
        show_usage
        exit 1
    fi
    
    # Setup error handling
    setup_error_handling
    
    print_header "$SCRIPT_NAME"
    [[ "$DRY_RUN" == "true" ]] && print_warning "DRY RUN MODE - No changes will be made"
    
    # Parse VLESS URL
    if ! parse_vless_url "$vless_url"; then
        exit 1
    fi
    
    # Validate parsed data
    if [[ -z "$V2RAY_UUID" ]] || [[ -z "$V2RAY_SERVER" ]] || [[ -z "$V2RAY_PORT" ]]; then
        log_error "Failed to extract required fields from VLESS URL"
        exit 1
    fi
    
    if [[ -z "$V2RAY_PUBLIC_KEY" ]] || [[ -z "$V2RAY_SHORT_ID" ]]; then
        log_warn "Reality keys not found in URL"
        log_info "V2Ray might not work properly without Reality configuration"
    fi
    
    # Create secrets file
    if ! create_secrets_file; then
        exit 1
    fi
    
    # Check SOPS setup and encrypt if available
    if check_sops_setup; then
        if ! encrypt_secrets; then
            log_warn "Secrets saved but not encrypted"
            echo
            echo "To encrypt manually:"
            echo "1. Setup SOPS: ./nix.sh sops"
            echo "2. Encrypt file: sops -e -i $SECRETS_FILE"
        fi
    else
        print_warning "SOPS not configured - secrets saved unencrypted"
        echo
        echo "To enable encryption:"
        echo "1. Run: ./nix.sh sops"
        echo "2. Then: sops -e -i $SECRETS_FILE"
    fi
    
    # Show completion message
    echo
    print_success "V2Ray configuration complete!"
    
    # Show next steps
    show_next_steps
    
    exit 0
}

# Run main function
main "$@"