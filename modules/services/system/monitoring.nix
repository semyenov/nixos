{ config, pkgs, lib, ... }:

{
  options.services.monitoring = {
    enable = lib.mkEnableOption "system monitoring and alerting";

    prometheus = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Prometheus monitoring";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Prometheus web interface port";
      };
    };

    grafana = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Grafana dashboards";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Grafana web interface port";
      };
    };

    alerts = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable system alerts";
      };

      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Email address for alerts";
      };
    };
  };

  config = lib.mkIf config.services.monitoring.enable {
    # Basic system monitoring tools
    environment.systemPackages = with pkgs; [
      # System monitoring
      htop
      btop
      iotop
      nethogs
      iftop
      nmon
      dstat
      sysstat
      lm_sensors

      # Resource monitoring
      ncdu # Disk usage analyzer
      duf # Better df
      dust # Directory disk usage

      # Network monitoring
      vnstat
      bmon
      nload
      speedtest-cli

      # Process monitoring
      procps
      psmisc
      lsof

      # Log monitoring
      lnav
      multitail

      # Hardware monitoring
      smartmontools
      nvtopPackages.nvidia
      intel-gpu-tools

      # Performance analysis
      perf-tools
      sysdig
      bpftrace
    ];

    # Prometheus configuration
    services.prometheus = lib.mkIf config.services.monitoring.prometheus.enable {
      enable = true;
      port = config.services.monitoring.prometheus.port;

      exporters = {
        node = {
          enable = true;
          enabledCollectors = [
            "systemd"
            "diskstats"
            "filesystem"
            "loadavg"
            "meminfo"
            "netdev"
            "stat"
            "time"
            "uname"
            "vmstat"
            "processes"
            "logind"
          ];
        };

        systemd.enable = true;
        nginx.enable = config.services.nginx.enable;
        postgres.enable = config.services.postgresql.enable;
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [{
            targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
          }];
        }
      ];

      rules = lib.mkIf config.services.monitoring.alerts.enable [
        ''
          groups:
            - name: system_alerts
              rules:
                - alert: HighCPUUsage
                  expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                  for: 10m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU usage detected"
                    description: "CPU usage is above 80% for more than 10 minutes"
                
                - alert: HighMemoryUsage
                  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High memory usage detected"
                    description: "Memory usage is above 90% for more than 5 minutes"
                
                - alert: DiskSpaceLow
                  expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"} / node_filesystem_size_bytes) * 100 < 10
                  for: 5m
                  labels:
                    severity: critical
                  annotations:
                    summary: "Low disk space"
                    description: "Disk space is below 10%"
                
                - alert: SystemdServiceFailed
                  expr: node_systemd_unit_state{state="failed"} > 0
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Systemd service in failed state"
                    description: "A systemd service is in failed state"
        ''
      ];
    };

    # Grafana configuration
    services.grafana = lib.mkIf config.services.monitoring.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_port = config.services.monitoring.grafana.port;
          domain = "localhost";
        };

        analytics.reporting_enabled = false;

        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };

      provision = {
        enable = true;

        datasources.settings.datasources = lib.mkIf config.services.monitoring.prometheus.enable [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString config.services.monitoring.prometheus.port}";
            isDefault = true;
          }
        ];

        dashboards.settings.providers = [
          {
            name = "Default";
            options.path = ./grafana-dashboards;
            disableDeletion = false;
            updateIntervalSeconds = 10;
          }
        ];
      };
    };

    # System monitoring services
    services = {
      # S.M.A.R.T monitoring for drives
      smartd = {
        enable = true;
        autodetect = true;
        notifications = lib.mkIf (config.services.monitoring.alerts.enable && config.services.monitoring.alerts.email != null) {
          mail = {
            enable = true;
            recipient = config.services.monitoring.alerts.email;
          };
        };
      };

      # Network statistics
      vnstat.enable = true;

      # System activity collection
      sysstat.enable = true;
    };

    # Systemd service for basic monitoring alerts
    systemd.services.system-monitor-alerts = lib.mkIf config.services.monitoring.alerts.enable {
      description = "System monitoring alerts";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        # Check CPU usage
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
          ${pkgs.libnotify}/bin/notify-send "High CPU Usage" "CPU usage is at $CPU_USAGE%"
        fi
        
        # Check memory usage
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        if [ $MEM_USAGE -gt 90 ]; then
          ${pkgs.libnotify}/bin/notify-send "High Memory Usage" "Memory usage is at $MEM_USAGE%"
        fi
        
        # Check disk usage
        DISK_USAGE=$(df -h / | tail -1 | awk '{print int($5)}')
        if [ $DISK_USAGE -gt 90 ]; then
          ${pkgs.libnotify}/bin/notify-send "Low Disk Space" "Root partition is $DISK_USAGE% full"
        fi
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    # Timer for periodic checks
    systemd.timers.system-monitor-alerts = lib.mkIf config.services.monitoring.alerts.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "10min";
      };
    };

    # Open firewall ports if needed
    networking.firewall.allowedTCPPorts = lib.mkMerge [
      (lib.mkIf config.services.monitoring.prometheus.enable [ config.services.monitoring.prometheus.port ])
      (lib.mkIf config.services.monitoring.grafana.enable [ config.services.monitoring.grafana.port ])
    ];
  };
}
