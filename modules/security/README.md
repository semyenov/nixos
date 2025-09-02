# Security Modules

Security-focused modules for system hardening, secrets management, and network protection.

## Modules

### `sops.nix`
SOPS (Secrets OPerationS) integration for encrypted secrets:
- Age key management
- Secret decryption at runtime
- Integration with systemd services
- **Must be loaded before modules that use secrets**

### `firewall.nix`
Advanced firewall configuration:
- Rate limiting for SSH and other services
- DDoS protection rules
- Fail2ban integration
- Port knocking support (optional)
- Logging of suspicious activity

### `hardening.nix`
System hardening profiles:
- **minimal**: Basic security hardening
- **standard**: Balanced security for workstations
- **hardened**: Maximum security for servers
- Kernel hardening options
- Systemd service hardening
- AppArmor/SELinux support (optional)

## Usage

```nix
# Enable security modules with standard profile
security.hardening = {
  enable = true;
  profile = "standard";
};

# Configure firewall
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 80 443 ];
};
```

## Configuration Options

Key options:
- `security.hardening.profile` - Security profile selection
- `security.hardening.enableSystemdHardening` - Harden systemd services
- `security.hardening.enableKernelHardening` - Enable kernel security features
- `networking.firewall.logRefusedConnections` - Log blocked connections
- `services.fail2ban.enable` - Enable intrusion prevention

## Dependencies

- `sops.nix` must be enabled for modules using encrypted secrets
- Firewall rules may conflict with some services

## Best Practices

1. Always use SOPS for sensitive data (passwords, API keys, certificates)
2. Start with "standard" hardening profile and adjust as needed
3. Regularly review firewall logs for suspicious activity
4. Keep fail2ban enabled on internet-facing systems
5. Test hardening changes in VM before production

## Priority

**Priority: 80** - Security modules load early to ensure protection is in place before services start.