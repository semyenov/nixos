{ config, pkgs, lib, ... }:

{
  options.services.backup = {
    enable = lib.mkEnableOption "automatic backup service";
    
    provider = lib.mkOption {
      type = lib.types.enum [ "borg" "restic" ];
      default = "borg";
      description = "Backup provider to use";
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/nixos";
      description = "Backup repository location";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home"
        "/etc/nixos"
        "/var/lib"
      ];
      description = "Paths to backup";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home/*/.cache"
        "/home/*/.local/share/Trash"
        "/home/*/Downloads"
        "/home/*/.npm"
        "/home/*/.cargo"
        "/home/*/.rustup"
        "*.tmp"
        "*.temp"
        "*.log"
        "node_modules"
        "target"
        "dist"
        ".git"
      ];
      description = "Patterns to exclude from backup";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Backup schedule (systemd timer format)";
    };

    retention = lib.mkOption {
      type = lib.types.attrs;
      default = {
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };
      description = "Backup retention policy";
    };
  };

  config = lib.mkIf config.services.backup.enable (
    if config.services.backup.provider == "borg" then {
      # BorgBackup configuration
      services.borgbackup.jobs."system-backup" = {
        paths = config.services.backup.paths;
        exclude = config.services.backup.exclude;
        repo = config.services.backup.repository;
        
        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat /run/secrets/backup-passphrase";
        };
        
        compression = "auto,zstd";
        startAt = config.services.backup.schedule;
        
        prune.keep = config.services.backup.retention;
        
        # Pre and post backup hooks
        preHook = ''
          echo "Starting backup at $(date)"
        '';
        
        postHook = ''
          echo "Backup completed at $(date)"
          ${pkgs.libnotify}/bin/notify-send "Backup Complete" "System backup finished successfully"
        '';
        
        # Environment
        environment = {
          BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
          BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes";
        };
      };

      # Install borg and related tools
      environment.systemPackages = with pkgs; [
        borgbackup
        borgmatic
      ];

      # Create backup directory if local
      systemd.tmpfiles.rules = lib.mkIf (lib.hasPrefix "/" config.services.backup.repository) [
        "d ${config.services.backup.repository} 0700 root root -"
      ];
    }
    else {
      # Restic configuration
      services.restic.backups."system-backup" = {
        paths = config.services.backup.paths;
        exclude = config.services.backup.exclude;
        repository = config.services.backup.repository;
        
        passwordFile = "/run/secrets/backup-passphrase";
        
        timerConfig = {
          OnCalendar = config.services.backup.schedule;
          Persistent = true;
        };
        
        pruneOpts = [
          "--keep-daily ${toString config.services.backup.retention.daily}"
          "--keep-weekly ${toString config.services.backup.retention.weekly}"
          "--keep-monthly ${toString config.services.backup.retention.monthly}"
          "--keep-yearly ${toString config.services.backup.retention.yearly}"
        ];
        
        # Initialize repository if it doesn't exist
        initialize = true;
        
        # Extra backup options
        extraBackupArgs = [
          "--compression=max"
          "--verbose=2"
        ];
      };

      # Install restic and related tools
      environment.systemPackages = with pkgs; [
        restic
        autorestic
      ];
    }
  );
}