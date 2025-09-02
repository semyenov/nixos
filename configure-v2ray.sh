#!/usr/bin/env bash
# V2Ray Configuration Helper
# This script helps configure V2Ray with a VLESS connection string

set -euo pipefail

# Global variable for secrets file
SECRETS_FILE="secrets/v2ray.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Parse VLESS URL
parse_vless_url() {
    local url="$1"
    
    # URL decode function
    urldecode() {
        local url_encoded="${1//+/ }"
        printf '%b' "${url_encoded//%/\\x}"
    }
    
    # Extract base components
    local uuid=$(echo "$url" | grep -oP 'vless://\K[^@]+')
    local server=$(echo "$url" | grep -oP '@\K[^:]+')
    local port=$(echo "$url" | grep -oP ':\K[0-9]+')
    
    # Extract full query string (everything between ? and #)
    local query=$(echo "$url" | grep -oP '\?\K[^#]+')
    
    # Parse query parameters
    local public_key=""
    local short_id=""
    local sni=""
    local fingerprint=""
    local spx=""
    
    # Parse each parameter
    IFS='&' read -ra PARAMS <<< "$query"
    for param in "${PARAMS[@]}"; do
        IFS='=' read -r key value <<< "$param"
        case "$key" in
            pbk) public_key="$value" ;;
            sid) short_id="$value" ;;
            sni) sni="$value" ;;
            fp) fingerprint="$value" ;;
            spx) spx=$(urldecode "$value") ;;
        esac
    done
    
    echo "UUID: $uuid"
    echo "Server: $server"
    echo "Port: $port"
    echo "Public Key: $public_key"
    echo "Short ID: $short_id"
    echo "SNI: $sni"
    echo "Fingerprint: $fingerprint"
    echo "SpiderX: $spx"
    
    # Export for use in other functions
    export V2RAY_UUID="$uuid"
    export V2RAY_SERVER="$server"
    export V2RAY_PORT="$port"
    export V2RAY_PUBLIC_KEY="$public_key"
    export V2RAY_SHORT_ID="$short_id"
}

# Create V2Ray secrets file
create_secrets_file() {    
    print_warning "Creating V2Ray secrets file..."
    
    cat > "$SECRETS_FILE" <<EOF
# V2Ray configuration secrets
# Auto-generated from VLESS connection string

v2ray:
  server_address: "$V2RAY_SERVER"
  server_port: $V2RAY_PORT
  user_id: "$V2RAY_UUID"
  public_key: "$V2RAY_PUBLIC_KEY"
  short_id: "$V2RAY_SHORT_ID"
EOF
    
    print_success "Created $SECRETS_FILE"
}

# Main function
main() {
    echo -e "${BLUE}V2Ray Configuration Helper${NC}"
    echo
    
    # Check if VLESS URL is provided
    if [ $# -eq 0 ]; then
        print_error "Please provide a VLESS connection string"
        echo "Usage: $0 'vless://...'"
        exit 1
    fi
    
    local vless_url="$1"
    
    # Validate VLESS URL format
    if [[ ! "$vless_url" =~ ^vless:// ]]; then
        print_error "Invalid VLESS URL format"
        echo "URL should start with 'vless://'"
        exit 1
    fi
    
    print_warning "Parsing VLESS connection string..."
    parse_vless_url "$vless_url"
    echo
    
    # Check if secrets directory exists
    if [ ! -d "secrets" ]; then
        print_warning "Creating secrets directory..."
        mkdir -p secrets
    fi
    
    # Create secrets file
    create_secrets_file
    
    # Check if SOPS is configured
    if [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
        print_error "SOPS age key not found!"
        echo
        echo "Please run the setup script first to configure SOPS:"
        echo "  ${YELLOW}./setup.sh sops${NC}"
        echo
        echo "The unencrypted secrets file has been saved to: $SECRETS_FILE"
        echo "You can encrypt it manually after setting up SOPS with:"
        echo "  ${YELLOW}sops -e -i $SECRETS_FILE${NC}"
        exit 1
    fi
    
    # Check if .sops.yaml has actual keys configured
    if ! grep -q "age1" .sops.yaml 2>/dev/null || grep -q "# - \*user_semyenov" .sops.yaml 2>/dev/null; then
        print_error "SOPS keys not configured in .sops.yaml!"
        echo
        echo "The V2Ray secrets file has been created but not encrypted."
        echo
        echo "To fix this:"
        echo "1. Run the setup script to configure SOPS:"
        echo "   ${YELLOW}./setup.sh sops${NC}"
        echo
        echo "2. Make sure .sops.yaml has your age public key uncommented"
        echo
        echo "3. Then encrypt the secrets file:"
        echo "   ${YELLOW}sops -e -i $SECRETS_FILE${NC}"
        echo
        echo "Current secrets saved (unencrypted) to: ${YELLOW}$SECRETS_FILE${NC}"
        exit 1
    fi
    
    # Encrypt with SOPS
    print_warning "Encrypting secrets with SOPS..."
    if sops -e -i "$SECRETS_FILE"; then
        print_success "Secrets encrypted successfully"
    else
        print_error "Failed to encrypt secrets"
        echo "The unencrypted secrets file has been saved to: $SECRETS_FILE"
        echo "Check your .sops.yaml configuration and try:"
        echo "  ${YELLOW}sops -e -i $SECRETS_FILE${NC}"
        exit 1
    fi
    
    echo
    print_success "V2Ray configuration complete!"
    echo
    echo "Next steps:"
    echo "1. Enable V2Ray in your host configuration:"
    echo "   ${YELLOW}services.v2ray.enable = true;${NC}"
    echo
    echo "2. Rebuild your system:"
    echo "   ${YELLOW}sudo nixos-rebuild switch --flake .#nixos${NC}"
    echo
    echo "3. Check V2Ray status:"
    echo "   ${YELLOW}systemctl status v2ray${NC}"
    echo
    echo "4. Configure applications to use proxy:"
    echo "   SOCKS5: ${YELLOW}127.0.0.1:1080${NC}"
    echo "   HTTP:   ${YELLOW}127.0.0.1:8118${NC}"
}

# Run main function
main "$@"