#!/usr/bin/env bash

set -e

echo "🔧 NixOS Configuration Fix and Switch"
echo "======================================"
echo ""
echo "Discord package was causing download issues and has been commented out."
echo "You can re-enable it later when the download servers are working."
echo ""
echo "Starting system rebuild..."
echo ""

# Try to switch
sudo nixos-rebuild switch --flake .#nixos

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Your system is now running the new modular configuration!"
    echo ""
    echo "What's new:"
    echo "  • Flakes-based configuration for reproducibility"
    echo "  • Home Manager for user environment management"
    echo "  • Modular structure for easy maintenance"
    echo "  • Security hardening with firewall and fail2ban"
    echo "  • Performance optimizations (ZRAM, tmpfs, etc.)"
    echo "  • Complete development environment"
    echo ""
    echo "To re-enable Discord later:"
    echo "  1. Edit users/semyenov/home.nix"
    echo "  2. Uncomment the discord line"
    echo "  3. Run: sudo nixos-rebuild switch --flake .#nixos"
    echo ""
    echo "Useful commands:"
    echo "  • Update flakes: nix flake update"
    echo "  • Rollback: sudo nixos-rebuild switch --rollback"
    echo "  • Garbage collect: sudo nix-collect-garbage -d"
else
    echo ""
    echo "❌ Build failed. Check the errors above."
    echo ""
    echo "Common fixes:"
    echo "  1. Check network connection"
    echo "  2. Try with --show-trace for detailed errors"
    echo "  3. Comment out problematic packages temporarily"
fi