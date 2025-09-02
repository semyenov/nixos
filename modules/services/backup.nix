{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.backup;
in
{
  options.services.backup = {
    enable = mkEnableOption "automatic backup service";
    
    mode = mkOption {
      type = types.enum [ "simple" "advanced" ];
      default = "simple";
      description = "Backup mode: simple (borg only) or advanced (borg/restic choice)";
    };
    
    provider = mkOption {
      type = types.enum [ "borg" "restic" ];
      default = "borg";
      description = "Backup provider to use (only used in advanced mode)";
    };

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

    schedule = mkOption {
      type = types.str;
      default = "daily";
      description = "Backup schedule (systemd timer format)";
    };

    retention = {
      daily = mkOption {
        type = types.int;
        default = 7;
        description = "Number of daily backups to keep";
      };
      
      weekly = mkOption {
        type = types.int;
        default = 4;
        description = "Number of weekly backups to keep";
      };
      
      monthly = mkOption {
        type = types.int;
        default = 6;
        description = "Number of monthly backups to keep";
      };
      
      yearly = mkOption {
        type = types.int;
        default = 2;
        description = "Number of yearly backups to keep";
      };
    };
    
    encryption = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable encryption using SOPS secrets";
      };
      
      passphraseFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to SOPS secret containing the encryption passphrase";
      };
    };
    
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable backup monitoring and notifications";
      };
      
      alertDays = mkOption {
        type = types.int;
        default = 2;
        description = "Alert if backup is older than this many days";
      };
    };
  };

  config = mkIf cfg.enable (
    # Simple mode - Borg only with full features
    if cfg.mode == "simple" || cfg.provider == "borg" then {
      # SOPS secret for backup encryption passphrase
      sops.secrets = mkIf cfg.encryption.enable {
        "backup/passphrase" = {
          sopsFile = ../../secrets/backup.yaml;
          mode = "0400";
          owner = "root";
        };
      };

      # BorgBackup configuration
      services.borgbackup.jobs."system-backup" = {
        paths = cfg.paths;
        exclude = cfg.exclude;
        repo = cfg.repository;
        
        # Encryption configuration
        encryption = if cfg.encryption.enable then {
          mode = "repokey-blake2";
          passCommand = if cfg.encryption.passphraseFile != null then
            "cat ${cfg.encryption.passphraseFile}"
          else if config.sops.secrets ? "backup/passphrase" then
            "cat ${config.sops.secrets."backup/passphrase".path}"
          else
            "echo 'WARNING_NO_PASSPHRASE_SET'";
        } else {
          mode = "none";
        };
        
        # Compression settings
        compression = "auto,zstd,10";
        
        # Schedule
        startAt = cfg.schedule;
        
        # Retention policy
        prune.keep = {
          daily = cfg.retention.daily;
          weekly = cfg.retention.weekly;
          monthly = cfg.retention.monthly;
          yearly = cfg.retention.yearly;
        };
        
        # Extra Borg options
        extraCreateArgs = "--stats --progress --checkpoint-interval 600";
        extraPruneArgs = "--stats --list";
        
        # Environment for better performance
        environment = {
          BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
          BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = if cfg.encryption.enable then "no" else "yes";
        };
        
        # Pre and post backup hooks
        preHook = ''
          echo "Starting backup at $(date)"
          # Ensure backup directory exists
          mkdir -p ${cfg.repository}
        '';
        
        postHook = ''
          echo "Backup completed at $(date)"
          # Send notification if desktop is available
          if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
            ${pkgs.libnotify}/bin/notify-send "Backup Complete" "System backup finished successfully" || true
          fi
        '';
        
        # On failure
        onFailure = ''
          echo "Backup failed at $(date)" >&2
          if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
            ${pkgs.libnotify}/bin/notify-send -u critical "Backup Failed" "System backup failed! Check logs" || true
          fi
        '';
      };

      # Install backup tools
      environment.systemPackages = with pkgs; [ 
        borgbackup
        borgmatic # Wrapper for borg
      ];

      # Create backup directory with proper permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.repository} 0700 root root -"
        "d /var/log/backup 0755 root root -"
      ];
      
      # Backup monitoring service
      systemd.services.backup-check = mkIf cfg.monitoring.enable {
        description = "Check backup status";
        after = [ "borgbackup-job-system-backup.service" ];
        
        script = ''
          # Check last backup time
          REPO="${cfg.repository}"
          if [ -d "$REPO" ]; then
            LAST_BACKUP=$(${pkgs.borgbackup}/bin/borg list --last 1 --format '{time}' "$REPO" 2>/dev/null || echo "never")
            echo "Last backup: $LAST_BACKUP"
            
            # Alert if backup is older than configured days
            if [ "$LAST_BACKUP" != "never" ]; then
              LAST_EPOCH=$(date -d "$LAST_BACKUP" +%s 2>/dev/null || echo 0)
              NOW_EPOCH=$(date +%s)
              AGE_DAYS=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
              
              if [ $AGE_DAYS -gt ${toString cfg.monitoring.alertDays} ]; then
                echo "WARNING: Last backup is $AGE_DAYS days old!"
                ${pkgs.libnotify}/bin/notify-send -u critical "Backup Warning" "Last backup is $AGE_DAYS days old!" || true
              fi
            fi
          fi
        '';
        
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
      
      # Timer for backup check
      systemd.timers.backup-check = mkIf cfg.monitoring.enable {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    }
    # Advanced mode with Restic option
    else {
      # SOPS secret for backup encryption passphrase  
      sops.secrets = mkIf cfg.encryption.enable {
        "backup/passphrase" = {
          sopsFile = ../../secrets/backup.yaml;
          mode = "0400";
          owner = "root";
        };
      };

      # Restic configuration
      services.restic.backups."system-backup" = {
        paths = cfg.paths;
        exclude = cfg.exclude;
        repository = cfg.repository;
        
        passwordFile = if cfg.encryption.enable then
          (if cfg.encryption.passphraseFile != null then
            cfg.encryption.passphraseFile
          else if config.sops.secrets ? "backup/passphrase" then
            config.sops.secrets."backup/passphrase".path
          else
            "/dev/null")
        else
          "/dev/null";
        
        timerConfig = {
          OnCalendar = cfg.schedule;
          Persistent = true;
        };
        
        pruneOpts = [
          "--keep-daily ${toString cfg.retention.daily}"
          "--keep-weekly ${toString cfg.retention.weekly}"
          "--keep-monthly ${toString cfg.retention.monthly}"
          "--keep-yearly ${toString cfg.retention.yearly}"
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
  ) // {
    # Common assertions for all modes
    assertions = [
      {
        assertion = !cfg.encryption.enable || 
                   (cfg.encryption.passphraseFile != null || 
                    config.sops.secrets ? "backup/passphrase");
        message = "Backup encryption is enabled but no passphrase source is configured";
      }
      {
        assertion = cfg.retention.daily >= 1;
        message = "At least one daily backup must be retained";
      }
    ];
  };
}