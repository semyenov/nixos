{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.system.maintenance;
in
{
  options.system.maintenance = {
    autoUpdate = {
      enable = mkEnableOption "automatic system updates";

      schedule = mkOption {
        type = types.str;
        default = "04:00";
        example = "daily";
        description = ''
          When to run automatic updates. Can be a systemd calendar expression.
          Examples: "daily", "weekly", "04:00", "Sun 02:00"
        '';
      };

      flakeUrl = mkOption {
        type = types.str;
        default = "github:NixOS/nixpkgs/nixos-25.05";
        description = "Flake URL to update from";
      };

      allowReboot = mkOption {
        type = types.bool;
        default = false;
        description = "Allow automatic reboot after kernel updates";
      };

      rebootWindow = {
        start = mkOption {
          type = types.str;
          default = "02:00";
          description = "Start of reboot window (24h format)";
        };

        end = mkOption {
          type = types.str;
          default = "05:00";
          description = "End of reboot window (24h format)";
        };
      };

      enableNotifications = mkOption {
        type = types.bool;
        default = true;
        description = "Send notifications about updates";
      };

      onlySecurityUpdates = mkOption {
        type = types.bool;
        default = false;
        description = "Only apply security updates automatically";
      };
    };

    autoGarbageCollection = {
      enable = mkEnableOption "automatic garbage collection";

      schedule = mkOption {
        type = types.str;
        default = "weekly";
        description = "When to run garbage collection";
      };

      keepDays = mkOption {
        type = types.int;
        default = 14;
        description = "Keep generations newer than N days";
      };

      keepGenerations = mkOption {
        type = types.int;
        default = 5;
        description = "Keep at least N generations";
      };
    };

    monitoring = {
      enable = mkEnableOption "system health monitoring";

      diskSpaceThreshold = mkOption {
        type = types.int;
        default = 90;
        description = "Alert when disk usage exceeds this percentage";
      };

      enableSmartMonitoring = mkOption {
        type = types.bool;
        default = true;
        description = "Monitor SMART status of drives";
      };
    };
  };

  config = mkMerge [
    # Auto-update configuration
    (mkIf cfg.autoUpdate.enable {
      system.autoUpgrade = {
        enable = true;
        flake = cfg.autoUpdate.flakeUrl;
        dates = cfg.autoUpdate.schedule;
        randomizedDelaySec = "45min";
        persistent = true;

        # Allow reboot if configured
        allowReboot = cfg.autoUpdate.allowReboot;
        rebootWindow = mkIf cfg.autoUpdate.allowReboot {
          lower = cfg.autoUpdate.rebootWindow.start;
          upper = cfg.autoUpdate.rebootWindow.end;
        };
      };

      # Update notification service
      systemd.services.update-notifier = mkIf cfg.autoUpdate.enableNotifications {
        description = "Check for and notify about updates";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c '
              set -e
              
              # Check for updates
              OLD_GEN=$(readlink /run/current-system)
              
              # Try to build new generation
              if NEW_GEN=$(nixos-rebuild build --flake ${cfg.autoUpdate.flakeUrl} 2>&1); then
                if [ "$OLD_GEN" != "$(readlink result)" ]; then
                  # Updates available
                  echo "System updates are available"
                  
                  # Get list of updated packages
                  ${pkgs.nvd}/bin/nvd diff "$OLD_GEN" result || true
                  
                  # Send notification (you can customize this)
                  echo "Updates available for $(hostname)" | \
                    ${pkgs.systemd}/bin/systemd-cat -t update-notifier -p notice
                fi
              fi
            '
          '';
        };
      };

      systemd.timers.update-notifier = mkIf cfg.autoUpdate.enableNotifications {
        description = "Check for updates daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })

    # Garbage collection
    (mkIf cfg.autoGarbageCollection.enable {
      nix.gc = {
        automatic = true;
        dates = cfg.autoGarbageCollection.schedule;
        options = "--delete-older-than ${toString cfg.autoGarbageCollection.keepDays}d";
        persistent = true;
      };

      # Advanced garbage collection with generation limits
      systemd.services.nix-gc-advanced = {
        description = "Advanced Nix garbage collection";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c '
              set -e
              
              # Keep minimum number of generations
              GENS=$(nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l)
              
              if [ "$GENS" -gt "${toString cfg.autoGarbageCollection.keepGenerations}" ]; then
                # Delete old generations but keep minimum
                TO_DELETE=$((GENS - ${toString cfg.autoGarbageCollection.keepGenerations}))
                nix-env --delete-generations +$TO_DELETE --profile /nix/var/nix/profiles/system
              fi
              
              # Run garbage collection
              nix-collect-garbage --delete-older-than ${toString cfg.autoGarbageCollection.keepDays}d
              
              # Optimize store
              nix-store --optimise
              
              # Report disk usage
              echo "Nix store size after GC: $(du -sh /nix/store | cut -f1)"
              df -h /nix/store
            '
          '';
        };
      };

      systemd.timers.nix-gc-advanced = {
        description = "Advanced Nix garbage collection timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.autoGarbageCollection.schedule;
          Persistent = true;
        };
      };
    })

    # System monitoring
    (mkIf cfg.monitoring.enable {
      # Disk space monitoring
      systemd.services.disk-space-monitor = {
        description = "Monitor disk space usage";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c '
              set -e
              
              # Check disk usage
              USAGE=$(df /nix/store | tail -1 | awk "{print int(\$5)}")
              
              if [ "$USAGE" -gt "${toString cfg.monitoring.diskSpaceThreshold}" ]; then
                echo "WARNING: Disk usage is at $USAGE%%" | \
                  ${pkgs.systemd}/bin/systemd-cat -t disk-monitor -p warning
                
                # Trigger emergency GC if critically low
                if [ "$USAGE" -gt 95 ]; then
                  echo "CRITICAL: Running emergency garbage collection"
                  nix-collect-garbage --delete-older-than 7d
                fi
              fi
            '
          '';
        };
      };

      systemd.timers.disk-space-monitor = {
        description = "Monitor disk space hourly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
        };
      };

      # SMART monitoring
      services.smartd = mkIf cfg.monitoring.enableSmartMonitoring {
        enable = true;
        autodetect = true;
        notifications = {
          wall.enable = true;
          mail = {
            enable = false; # Set to true if you have mail configured
            recipient = "root";
          };
        };
        defaults.monitored = "-a -o on -S on -n standby,q -W 4,35,45";
      };

      # System health check
      systemd.services.system-health-check = {
        description = "Comprehensive system health check";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c '
              set -e
              
              echo "=== System Health Check ==="
              echo "Date: $(date)"
              echo ""
              
              # Check failed services
              echo "Failed services:"
              systemctl --failed --no-pager || true
              echo ""
              
              # Check disk usage
              echo "Disk usage:"
              df -h / /nix/store /boot || true
              echo ""
              
              # Check memory
              echo "Memory usage:"
              free -h
              echo ""
              
              # Check load average
              echo "Load average:"
              uptime
              echo ""
              
              # Check for security updates (if applicable)
              echo "Checking for security updates..."
              # This would need integration with vulnerability databases
              
              echo "=== Health Check Complete ==="
            ' | ${pkgs.systemd}/bin/systemd-cat -t health-check
          '';
        };
      };

      systemd.timers.system-health-check = {
        description = "Daily system health check";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    })

    # Common packages for maintenance
    {
      environment.systemPackages = with pkgs; [
        nvd # Nix version diff tool
        nix-tree # Visualize dependencies
        ncdu # Disk usage analyzer
      ] ++ optionals cfg.monitoring.enable [
        smartmontools # SMART monitoring
        iotop # I/O monitoring
        htop # Process monitoring
      ];
    }
  ];
}
