#!/usr/bin/env bash

set -e

echo "🚀 NixOS Configuration Apply Script"
echo "===================================="
echo ""
echo "This script will apply your new modular NixOS configuration."
echo ""
echo "Configuration includes:"
echo "  ✓ Flakes for reproducible builds"
echo "  ✓ Home Manager for user environment"
echo "  ✓ Security hardening (firewall, fail2ban)"
echo "  ✓ Performance optimizations"
echo "  ✓ Complete TypeScript development environment"
echo "  ✓ Docker and container tools"
echo "  ✓ SOPS for secrets management"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

echo ""
echo "🔧 Building and switching to new configuration..."
echo ""

# Apply the configuration
sudo nixos-rebuild switch --flake .#nixos

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Your system is now running the new configuration."
    echo ""
    echo "Next steps:"
    echo "  1. Test your applications to ensure everything works"
    echo "  2. Set up SOPS for secrets (see secrets/README.md)"
    echo "  3. Customize your user configuration in users/semyenov/home.nix"
    echo ""
    echo "Useful commands:"
    echo "  - View current generation: nixos-rebuild list-generations"
    echo "  - Rollback if needed: sudo nixos-rebuild switch --rollback"
    echo "  - Update flakes: nix flake update"
    echo "  - Garbage collect: sudo nix-collect-garbage -d"
else
    echo ""
    echo "❌ Configuration switch failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check the error messages above"
    echo "  2. Run with --show-trace for detailed errors:"
    echo "     sudo nixos-rebuild switch --flake .#nixos --show-trace"
    echo "  3. You can always rollback to the previous configuration:"
    echo "     sudo nixos-rebuild switch --rollback"
fi