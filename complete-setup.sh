#!/usr/bin/env bash

echo "🎉 Completing NixOS Configuration Setup"
echo "======================================="
echo ""
echo "The system configuration is already active!"
echo "Now fixing Home Manager to handle existing files..."
echo ""

# Apply the updated configuration
sudo nixos-rebuild switch --flake .#nixos

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Perfect! Your new modular NixOS configuration is fully active!"
    echo ""
    echo "🚀 What's Now Active:"
    echo "  ✓ Flakes-based configuration"
    echo "  ✓ Modular structure"
    echo "  ✓ Home Manager (with automatic backups)"
    echo "  ✓ Security hardening (firewall, fail2ban)"
    echo "  ✓ Performance optimizations"
    echo "  ✓ Docker and Podman"
    echo "  ✓ Complete dev environment"
    echo ""
    echo "📝 New Services Running:"
    systemctl status --no-pager fail2ban docker thermald earlyoom | grep "Active:" || true
    echo ""
    echo "🔧 Quick Commands:"
    echo "  • Check Home Manager: systemctl status home-manager-semyenov"
    echo "  • Update flakes: nix flake update"
    echo "  • Clean old generations: sudo nix-collect-garbage -d"
    echo "  • Rollback if needed: sudo nixos-rebuild switch --rollback"
    echo ""
    echo "Your old config files were backed up with .backup extension"
else
    echo "❌ Something went wrong. Check the errors above."
fi