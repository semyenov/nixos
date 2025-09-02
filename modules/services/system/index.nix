# System Services Module Index
# System-level services for monitoring, backup, and maintenance
# Critical for system health and data protection
#
# Priority: 75 - Higher priority than general services
# Maintainers: system

{ config, pkgs, lib, ... }:

{
  imports = [
    ./backup.nix # Automated backup with BorgBackup
    ./monitoring.nix # System monitoring with Prometheus/Grafana
  ];
}
