{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.simpleBackup;
in
{
  options.services.simpleBackup = {
    enable = mkEnableOption "automatic backup service";
  };

  config = mkIf cfg.enable {
    # Basic backup configuration with Borg
    services.borgbackup.jobs."system-backup" = {
      paths = [
        "/home"
        "/etc/nixos"
        "/var/lib"
      ];
      
      exclude = [
        "/home/*/.cache"
        "/home/*/Downloads"
        "*.tmp"
        "node_modules"
      ];
      
      repo = "/var/backup/nixos";
      
      encryption = {
        mode = "none"; # Can be configured with SOPS later
      };
      
      compression = "auto,zstd";
      startAt = "daily";
      
      prune.keep = {
        daily = 7;
        weekly = 4;
        monthly = 6;
      };
    };

    # Install borg
    environment.systemPackages = [ pkgs.borgbackup ];

    # Create backup directory
    systemd.tmpfiles.rules = [
      "d /var/backup/nixos 0700 root root -"
    ];
  };
}