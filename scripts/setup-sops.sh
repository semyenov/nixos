#!/usr/bin/env bash
# SOPS Age Key Setup Script
# Automated setup for SOPS encryption keys

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up SOPS encryption keys...${NC}"

# Generate user age key if it doesn't exist
AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [ ! -f "$AGE_KEY_FILE" ]; then
    mkdir -p "$(dirname "$AGE_KEY_FILE")"
    age-keygen -o "$AGE_KEY_FILE"
    echo -e "${GREEN}✓ Generated user age key${NC}"
else
    echo -e "${YELLOW}User age key already exists${NC}"
fi

# Extract user public key
USER_PUBLIC_KEY=$(grep "public key:" "$AGE_KEY_FILE" | cut -d: -f2 | tr -d ' ')
echo -e "User public key: ${GREEN}$USER_PUBLIC_KEY${NC}"

# Get host SSH key
HOST_PUBLIC_KEY=""
if [ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]; then
    HOST_PUBLIC_KEY=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
    echo -e "Host public key: ${GREEN}$HOST_PUBLIC_KEY${NC}"
else
    echo -e "${RED}Warning: Host SSH key not found${NC}"
fi

# Create proper .sops.yaml
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

echo -e "${GREEN}✓ Created .sops.yaml with proper keys${NC}"
echo
echo "SOPS is now configured! You can encrypt secrets with:"
echo -e "  ${YELLOW}sops secrets/v2ray.yaml${NC}"