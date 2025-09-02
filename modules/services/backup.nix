{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.backup;
  centralConfig = import ../../lib/config.nix;
  utils = import ../../lib/module-utils.nix { inherit lib; };
  backupConfig = centralConfig.backup;
in
{
  options.services.backup = {
    enable = utils.mkServiceEnableOption "backup" "automatic system backup using BorgBackup";

    repository = utils.mkPathOption {
      default = backupConfig.defaultRepository;
      description = ''
        Location of the backup repository.
        Can be a local path or a remote repository.
      '';
      example = "/mnt/backup/nixos";
    };

    paths = utils.mkStringListOption {
      default = backupConfig.defaultPaths;
      description = ''
        List of paths to include in the backup.
        These paths will be backed up recursively.
      '';
      example = [ "/home" "/etc" "/var/lib" ];
    };

    exclude = utils.mkStringListOption {
      default = backupConfig.defaultExcludes;
      description = ''
        Patterns to exclude from backup.
        Uses BorgBackup pattern matching syntax.
      '';
      example = [ "*.cache" "*/tmp/*" "node_modules" ];
    };

    schedule = utils.mkScheduleOption {
      default = backupConfig.defaultSchedule;
      description = ''
        Backup schedule in systemd timer format.
        Common values: "daily", "weekly", "monthly", or custom like "*-*-* 02:00:00"
      '';
    };
  };

  config = mkIf cfg.enable {
    # Assertions for backup configuration
    assertions = [
      (utils.mkAssertion
        (cfg.repository != "")
        "Backup repository path cannot be empty")
      (utils.mkAssertion
        (length cfg.paths > 0)
        "At least one path must be specified for backup")
    ];

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
        daily = backupConfig.retention.keepDaily;
        weekly = backupConfig.retention.keepWeekly;
        monthly = backupConfig.retention.keepMonthly;
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
