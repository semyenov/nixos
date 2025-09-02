# Services Modules

This directory contains service configuration modules organized by category.

## Structure

```
services/
├── network/          # Network-related services
│   ├── networking.nix   # NetworkManager and DNS configuration
│   └── v2ray-secrets.nix # V2Ray proxy with SOPS secrets
├── system/           # System-level services
│   ├── backup.nix      # BorgBackup configuration
│   └── monitoring.nix  # Prometheus and Grafana monitoring
├── audio.nix         # PipeWire audio system
└── docker.nix        # Docker container runtime
```

## Network Services

### networking.nix
Configures NetworkManager and DNS settings.

**Options:**
- NetworkManager with wireless support
- DNS configuration with systemd-resolved
- Network tools installation

**Usage:**
```nix
# Enabled by default in all profiles
```

### v2ray-secrets.nix
V2Ray proxy service with SOPS-encrypted configuration.

**Features:**
- SOCKS5 proxy on port 1080
- HTTP proxy on port 8118
- VLESS protocol with Reality security
- Automatic secret management with SOPS

**Configuration:**
```nix
services.v2rayWithSecrets.enable = true;
```

**Requirements:**
- SOPS secrets configured in `secrets/v2ray.yaml`
- Required secrets:
  - `v2ray/server_address`
  - `v2ray/server_port`
  - `v2ray/user_id`
  - `v2ray/public_key`
  - `v2ray/short_id`

## System Services

### backup.nix
Automated backup service using BorgBackup.

**Features:**
- Scheduled backups (daily/weekly/monthly)
- Configurable retention policies
- Path exclusion patterns
- Compression with zstd

**Configuration:**
```nix
services.backup = {
  enable = true;
  repository = "/var/backup/nixos";
  paths = [ "/home" "/etc/nixos" ];
  schedule = "daily";
};
```

**Options:**
- `repository`: Backup destination (local or remote)
- `paths`: List of directories to backup
- `exclude`: Patterns to exclude
- `schedule`: Systemd timer format

### monitoring.nix
System monitoring with Prometheus and Grafana.

**Features:**
- Prometheus metrics collection
- Node exporter for system metrics
- Optional Grafana dashboards
- Configurable scrape intervals

**Configuration:**
```nix
services.monitoring = {
  enable = true;
  prometheus.enable = true;
  grafana.enable = true;
  nodeExporter.enable = true;
};
```

## Audio Service

### audio.nix
PipeWire audio system configuration.

**Features:**
- PipeWire with ALSA and PulseAudio compatibility
- WirePlumber session management
- Low-latency audio support
- Bluetooth audio support (optional)

**Configuration:**
```nix
# Enabled by default in desktop profiles
```

## Container Service

### docker.nix
Docker container runtime configuration.

**Features:**
- Docker daemon with systemd integration
- Auto-prune old containers and images
- Docker Compose support
- User group configuration

**Configuration:**
```nix
virtualisation.docker = {
  enable = true;
  enableOnBoot = true;
  autoPrune = {
    enable = true;
    dates = "weekly";
  };
};
```

## Common Patterns

### Enabling Services

Services can be enabled in multiple ways:

1. **In host configuration:**
```nix
# hosts/nixos/configuration.nix
services.backup.enable = true;
services.monitoring.enable = true;
```

2. **Through profiles:**
```nix
# Workstation profile enables Docker
# Server profile enables monitoring
imports = [ ./profiles/server.nix ];
```

3. **Conditionally:**
```nix
services.v2rayWithSecrets.enable = 
  config.networking.hostName == "laptop";
```

### Service Dependencies

Some services have dependencies:

- **v2ray-secrets.nix** → Requires SOPS configuration
- **monitoring.nix** → Requires network configuration
- **backup.nix** → Requires valid paths to exist

### Performance Considerations

Services are configured with performance in mind:

- Backup uses zstd compression (fast)
- Monitoring uses efficient scrape intervals
- Audio configured for low latency
- Docker with automatic cleanup

## Troubleshooting

### Service not starting

```bash
# Check service status
systemctl status service-name

# View logs
journalctl -xeu service-name

# Test configuration
nixos-rebuild test
```

### Backup issues

```bash
# Manual backup run
systemctl start borgbackup-job-system-backup

# Check backup repository
borg list /var/backup/nixos
```

### V2Ray connection issues

```bash
# Check V2Ray status
systemctl status v2ray

# Test proxy
curl -x socks5://127.0.0.1:1080 https://www.google.com

# View V2Ray logs
journalctl -u v2ray -f
```

### Docker permission issues

```bash
# Ensure user is in docker group
groups $USER

# Restart after group change
systemctl restart docker
```

## Best Practices

1. **Use central configuration** - Port numbers and settings in `lib/config.nix`
2. **Add assertions** - Validate configuration to prevent errors
3. **Document options** - Clear descriptions and examples
4. **Test changes** - Use `nixos-rebuild test` before switching
5. **Monitor resources** - Enable monitoring for production systems