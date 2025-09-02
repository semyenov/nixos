#!/usr/bin/env bash

set -e

echo "🔍 Testing NixOS configuration..."
echo ""

# Check flake
echo "1. Checking flake validity..."
nix flake check --no-build 2>&1 | grep -E "error|warning" || echo "✅ Flake structure is valid"

echo ""
echo "2. Building configuration (dry-run)..."
nixos-rebuild dry-build --flake .#nixos 2>&1 | grep -E "error|warning" || echo "✅ Configuration builds without errors"

echo ""
echo "3. Checking for evaluation errors..."
nix eval .#nixosConfigurations.nixos.config.system.build.toplevel 2>&1 | grep -E "error" || echo "✅ No evaluation errors"

echo ""
echo "Configuration test complete!"
echo ""
echo "To switch to this configuration, run:"
echo "  sudo nixos-rebuild switch --flake .#nixos"
echo ""
echo "Or use the provided script:"
echo "  ./switch.sh"