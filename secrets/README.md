# Secrets Management with SOPS

This directory contains encrypted secrets managed by SOPS (Secrets OPerationS).

## Setup

1. **Generate an age key:**
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Convert SSH host key to age (if using SSH keys):**
   ```bash
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. **Update `.sops.yaml`** with your public keys

4. **Create a secret file:**
   ```bash
   sops secrets/example.yaml
   ```

## Usage

### Creating a new secret file
```bash
sops secrets/my-secret.yaml
```

### Editing existing secrets
```bash
sops secrets/my-secret.yaml
```

### Example secret file structure
```yaml
# secrets/example.yaml
github_token: ghp_xxxxxxxxxxxxxxxxxxxx
docker_password: supersecretpassword
wifi_passwords:
  home: myHomeWifiPassword
  work: myWorkWifiPassword
```

## Accessing secrets in NixOS

Secrets are automatically decrypted during system activation and available at:
- `/run/secrets/secret_name` - for regular secrets
- As environment variables for services configured to use them

## Security Notes

1. **Never commit unencrypted secrets**
2. **Keep your age/SSH private keys secure**
3. **Use different keys for different environments**
4. **Rotate secrets regularly**
5. **Audit access to secrets**

## Troubleshooting

- If secrets aren't decrypting, check that your key is in the correct location
- Ensure the `.sops.yaml` file has the correct public keys
- Check system logs: `journalctl -u sops-nix`