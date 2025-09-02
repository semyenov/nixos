# Central configuration for NixOS modules
# This file contains all hardcoded values extracted from modules for better maintainability

{
  # Network Configuration
  network = {
    # Common ports used across modules
    ports = {
      # Development
      dev = {
        default = 3000;
        range = { from = 3000; to = 3010; };
        angular = 4200;
        vite = 5173;
        python = 8000;
        altHttp = 8080;
        altRange = { from = 8000; to = 8010; };
        php = 9000;
      };

      # Services
      services = {
        ssh = 22;
        http = 80;
        https = 443;
        wireguard = 51820;
      };

      # V2Ray
      v2ray = {
        socks = 1080;
        http = 8118;
      };

      # Monitoring
      monitoring = {
        prometheus = 9090;
        grafana = 3000;
        nodeExporter = 9100;
      };
    };

    # DNS servers
    dns = {
      primary = [ "8.8.8.8" "8.8.4.4" ];
      secondary = [ "1.1.1.1" "1.0.0.1" ];
      chinese = [ "223.5.5.5" "119.29.29.29" ];
    };

    # Private network ranges
    privateRanges = [
      "127.0.0.0/8"
      "::1"
      "192.168.0.0/16"
      "10.0.0.0/8"
      "172.16.0.0/12"
    ];

    # Docker specific
    docker = {
      bridge = "172.17.0.0/16";
      subnet = "172.16.0.0/12";
    };
  };

  # Performance Configuration
  performance = {
    # Memory settings (in bytes unless specified)
    memory = {
      minFreeKbytes = 65536;
      # Network buffers
      buffers = {
        rmemDefault = 262144;
        wmemDefault = 262144;
        rmemMax = 67108864;
        wmemMax = 67108864;
        tcpMem = "4096 262144 67108864";
      };
    };

    # Time settings (in milliseconds/seconds)
    timing = {
      schedCfsBandwidth = 3000; # microseconds
      dirtyExpireCentisecs = {
        performance = 3000;
        default = 1500;
      };
      dirtyWritebackCentisecs = {
        performance = 500;
        default = 1500;
      };
      tcpFinTimeout = 10;
      tcpKeepaliveTime = 60;
      tcpKeepaliveInterval = 10;
      tcpKeepaliveProbes = 6;
    };

    # Scheduler settings (in nanoseconds)
    scheduler = {
      performance = {
        migrationCost = 5000000;
        minGranularity = 10000000;
        wakeupGranularity = 15000000;
      };
      lowLatency = {
        migrationCost = 500000;
        minGranularity = 2250000;
        wakeupGranularity = 3000000;
        latency = 6000000;
      };
      throughput = {
        migrationCost = 50000000;
        minGranularity = 10000000;
        wakeupGranularity = 25000000;
      };
    };

    # Connection limits
    connections = {
      maxConntrack = 2000000;
      conntrackTimeout = 21600;
    };
  };

  # Backup Configuration
  backup = {
    defaultRepository = "/var/backup/nixos";
    defaultPaths = [
      "/home"
      "/etc/nixos"
      "/var/lib"
    ];
    defaultExcludes = [
      "/home/*/.cache"
      "/home/*/.local/share/Trash"
      "/home/*/Downloads"
      "*.tmp"
      "node_modules"
      ".git"
    ];
    defaultSchedule = "daily";
    retention = {
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 6;
    };
  };

  # Security Configuration
  security = {
    # Firewall rate limiting
    rateLimit = {
      ssh = {
        seconds = 60;
        hitcount = 4;
        longSeconds = 300;
        longHitcount = 10;
      };
      synFlood = {
        limit = "1/s";
        burst = 3;
      };
      portScan = {
        limit = "1/s";
        burst = 2;
      };
    };

    # Fail2ban settings
    fail2ban = {
      maxRetry = 3;
      banTime = "1h";
      banFactor = "2";
      maxBanTime = "168h"; # 1 week
      findTime = 600;
    };

    # Kernel panic settings
    kernel = {
      panicTimeout = 10; # seconds
    };
  };

  # Maintenance Configuration
  maintenance = {
    # Garbage collection
    gc = {
      defaultSchedule = "weekly";
      defaultKeepDays = 14;
      defaultKeepGenerations = 5;
    };

    # Auto-update
    update = {
      defaultSchedule = "04:00";
      rebootWindow = {
        start = "02:00";
        end = "05:00";
      };
    };

    # Monitoring thresholds
    monitoring = {
      diskSpaceThreshold = 90; # percentage
      memoryPressureThreshold = 10; # percentage
    };
  };

  # Development Configuration
  development = {
    # Node.js settings
    nodejs = {
      version = 22;
      globalPaths = {
        pnpm = "$HOME/.local/share/pnpm";
        npm = "$HOME/.npm-global";
      };
    };
  };

  # User Configuration
  users = {
    defaultShell = "zsh";
    defaultGroups = {
      normal = [ "networkmanager" "audio" "video" ];
      admin = [ "networkmanager" "wheel" "docker" "audio" "video" "input" "plugdev" ];
    };
  };

  # System Paths
  paths = {
    sopsAge = "~/.config/sops/age/keys.txt";
    stateVersion = "25.05";
  };
}

