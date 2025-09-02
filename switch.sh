#!/usr/bin/env bash

# Script to switch to the new NixOS configuration

set -e

echo "🔧 Switching to new NixOS configuration..."
echo ""
echo "This will:"
echo "  1. Build the new configuration"
echo "  2. Activate it as the current system"
echo "  3. Set it as the default boot option"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Switch to the new configuration
sudo nixos-rebuild switch --flake .#nixos

echo ""
echo "✅ Configuration switch complete!"
echo ""
echo "Your system is now running the new modular configuration with:"
echo "  - Flakes for reproducible builds"
echo "  - Home Manager for user environment"
echo "  - Enhanced security and performance"
echo ""
echo "If you encounter any issues, you can rollback with:"
echo "  sudo nixos-rebuild switch --rollback"