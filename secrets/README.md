# Secrets Management with SOPS

This directory contains encrypted secrets managed by SOPS (Secrets OPerationS) with age encryption.

## Quick Start

### Initial Setup

```bash
# Using Taskfile (recommended)
task setup:sops

# Or using legacy script
./nix.sh sops

# Or manually:
# 1. Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# 2. Get host SSH key (for system-level secrets)
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# 3. Update .sops.yaml with your keys
```

### V2Ray Configuration

```bash
# Configure V2Ray from VLESS URL (using Taskfile)
task v2ray:config URL='vless://UUID@server:port?pbk=...&sid=...'

# Or edit V2Ray secrets directly
task setup:sops:edit-v2ray

# Or manually create from template
cp secrets/v2ray.yaml.example secrets/v2ray.yaml
sops secrets/v2ray.yaml
```

## File Structure

```
secrets/
├── README.md           # This file
├── v2ray.yaml         # V2Ray configuration (encrypted)
└── v2ray.yaml.example # Template for V2Ray secrets
```

## Secret Format

### V2Ray Secrets (`v2ray.yaml`)

```yaml
v2ray:
  server_address: "example.com"
  server_port: 8080
  user_id: "uuid-here"
  public_key: "reality-public-key"
  short_id: "short-id"
```

### Creating New Secrets

```bash
# Create and edit a new secret file
sops secrets/my-service.yaml

# Edit existing secrets
sops secrets/v2ray.yaml

# Encrypt an existing plain file
sops -e -i secrets/my-service.yaml

# Decrypt to view (be careful!)
sops -d secrets/v2ray.yaml
```

## NixOS Integration

### Accessing Secrets in Configuration

Secrets are automatically decrypted during system activation:

```nix
# In your NixOS module
{
  sops.secrets."v2ray/server_address" = {
    sopsFile = ./secrets/v2ray.yaml;
    nestedKeys = true;
  };
  
  # Use the secret
  services.v2ray.config.server = 
    config.sops.secrets."v2ray/server_address".path;
}
```

### Secret Locations at Runtime

- **File secrets**: `/run/secrets/<name>`
- **Nested secrets**: `/run/secrets/<parent>/<child>`
- **Permissions**: Configurable per secret (owner, group, mode)

## SOPS Configuration (`.sops.yaml`)

The `.sops.yaml` file in the repository root defines:

1. **Encryption keys**: Age public keys for users and hosts
2. **Creation rules**: Which keys encrypt which files
3. **Path patterns**: Automatic key selection based on file paths

Example structure:
```yaml
keys:
  - &user_semyenov age1...  # User key
  - &host_nixos age1...     # Host key

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json)$
    key_groups:
      - age:
          - *user_semyenov
          - *host_nixos
```

## Security Best Practices

1. **Key Management**
   - Store age private key securely at `~/.config/sops/age/keys.txt`
   - Set restrictive permissions: `chmod 600 ~/.config/sops/age/keys.txt`
   - Never commit private keys

2. **Secret Rotation**
   - Regularly rotate sensitive credentials
   - Update both the secret and the service configuration
   - Test after rotation

3. **Access Control**
   - Use different keys for different environments
   - Limit secret access to required services only
   - Audit secret usage in NixOS modules

4. **Git Safety**
   - Never commit unencrypted `.yaml` files in this directory
   - Use `.gitignore` for temporary decrypted files
   - Always verify encryption: `file secrets/*.yaml` should show "data" not "text"

## Troubleshooting

### Common Issues

1. **Decryption fails during rebuild**
   ```bash
   # Check age key exists
   ls -la ~/.config/sops/age/keys.txt
   
   # Verify key in .sops.yaml matches
   grep "age1" ~/.config/sops/age/keys.txt
   grep "age1" .sops.yaml
   ```

2. **SOPS can't find keys**
   ```bash
   # Set SOPS_AGE_KEY_FILE if needed
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   ```

3. **Service can't read secrets**
   ```bash
   # Check secret was created
   sudo ls -la /run/secrets/
   
   # Check service logs
   journalctl -u <service-name>
   ```

4. **V2Ray specific issues**
   ```bash
   # Verify V2Ray secrets are encrypted
   file secrets/v2ray.yaml  # Should show "data"
   
   # Check V2Ray service
   systemctl status v2ray
   journalctl -u v2ray
   ```

### Useful Commands

```bash
# List all secrets in a file
sops -d secrets/v2ray.yaml | yq e 'keys' -

# Rotate encryption keys
sops rotate -i secrets/v2ray.yaml

# Check SOPS version
sops --version

# Validate .sops.yaml
sops --config .sops.yaml secrets/v2ray.yaml

# Emergency decrypt (use carefully!)
age -d -i ~/.config/sops/age/keys.txt secrets/v2ray.yaml
```

## Adding New Services

1. Create secret file:
   ```bash
   sops secrets/new-service.yaml
   ```

2. Add to NixOS module:
   ```nix
   sops.secrets."new-service/api_key" = {
     sopsFile = ./secrets/new-service.yaml;
   };
   ```

3. Use in service configuration:
   ```nix
   services.newService.apiKeyFile = 
     config.sops.secrets."new-service/api_key".path;
   ```

4. Enable service and rebuild:
   ```bash
   task rebuild
   # Or: ./nix.sh rebuild
   ```