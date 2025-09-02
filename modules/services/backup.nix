{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.backup;
in
{
  options.services.backup = {
    enable = mkEnableOption "automatic backup service";

    repository = mkOption {
      type = types.str;
      default = "/var/backup/nixos";
      description = "Backup repository location";
    };

    paths = mkOption {
      type = types.listOf types.str;
      default = [
        "/home"
        "/etc/nixos"
        "/var/lib"
      ];
      description = "Paths to backup";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [
        "/home/*/.cache"
        "/home/*/.local/share/Trash"
        "/home/*/Downloads"
        "*.tmp"
        "node_modules"
        ".git"
      ];
      description = "Patterns to exclude from backup";
    };

    schedule = mkOption {
      type = types.str;
      default = "daily";
      description = "Backup schedule (systemd timer format)";
    };
  };

  config = mkIf cfg.enable {
    # BorgBackup configuration
    services.borgbackup.jobs."system-backup" = {
      paths = cfg.paths;
      exclude = cfg.exclude;
      repo = cfg.repository;
      
      # Simple encryption
      encryption = {
        mode = "none";
      };
      
      compression = "auto,zstd";
      startAt = cfg.schedule;
      
      # Simple retention policy
      prune.keep = {
        daily = 7;
        weekly = 4;
        monthly = 6;
      };
    };

    # Install backup tools
    environment.systemPackages = with pkgs; [ 
      borgbackup
    ];

    # Create backup directory
    systemd.tmpfiles.rules = [
      "d ${cfg.repository} 0700 root root -"
    ];
  };
}