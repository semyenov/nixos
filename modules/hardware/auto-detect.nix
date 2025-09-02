{ config, pkgs, lib, ... }:

{
  options.hardware.autoDetect = {
    enable = lib.mkEnableOption "automatic hardware detection and configuration";

    cpu = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable CPU-specific optimizations";
      };
    };

    gpu = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable GPU auto-detection";
      };
    };

    storage = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable storage optimizations";
      };
    };

    network = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable network hardware optimizations";
      };
    };

    peripherals = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable peripheral device support";
      };
    };
  };

  config = lib.mkIf config.hardware.autoDetect.enable {
    # Boot configuration (all boot settings merged here)
    boot = {
      kernelModules = lib.mkMerge [
        # CPU modules
        (lib.mkIf config.hardware.autoDetect.cpu.enable (lib.mkMerge [
          # Intel CPU modules
          (lib.mkIf (builtins.elem "GenuineIntel" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null")))) [
            "kvm-intel"
            "intel_pstate"
            "coretemp"
            "intel_rapl"
            "intel_powerclamp"
          ])

          # AMD CPU modules  
          (lib.mkIf (builtins.elem "AuthenticAMD" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null")))) [
            "kvm-amd"
            "amd_pstate"
            "k10temp"
            "amd_energy"
          ])
        ]))

        # Peripheral modules
        (lib.mkIf config.hardware.autoDetect.peripherals.enable [
          "usbhid"
          "hid_generic"
          "hid_multitouch"
          "btusb"
          "btintel"
          "btbcm"
          "btrtl"
        ])
      ];

      # CPU microcode updates
      initrd.prepend = lib.mkIf config.hardware.autoDetect.cpu.enable (lib.mkMerge [
        (lib.mkIf (builtins.elem "GenuineIntel" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null"))))
          [ "${pkgs.microcodeIntel}/intel-ucode.img" ])
        (lib.mkIf (builtins.elem "AuthenticAMD" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null"))))
          [ "${pkgs.microcodeAmd}/amd-ucode.img" ])
      ]);

      # Kernel sysctl settings
      kernel.sysctl = lib.mkMerge [
        # Storage optimizations
        (lib.mkIf config.hardware.autoDetect.storage.enable {
          "vm.swappiness" = 10;
          "vm.vfs_cache_pressure" = 50;
        })

        # Network optimizations
        (lib.mkIf config.hardware.autoDetect.network.enable {
          "net.core.netdev_max_backlog" = 5000;
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.core.default_qdisc" = "cake";
          "net.ipv4.tcp_fastopen" = 3;
          "net.ipv4.tcp_mtu_probing" = 1;
          "net.core.rmem_max" = 134217728;
          "net.core.wmem_max" = 134217728;
          "net.ipv4.tcp_rmem" = "4096 87380 134217728";
          "net.ipv4.tcp_wmem" = "4096 65536 134217728";
        })
      ];
    };

    # Hardware packages based on detected hardware
    hardware = {
      # CPU frequency scaling
      cpu.intel.updateMicrocode = lib.mkIf config.hardware.autoDetect.cpu.enable
        (builtins.elem "GenuineIntel" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null"))));
      cpu.amd.updateMicrocode = lib.mkIf config.hardware.autoDetect.cpu.enable
        (builtins.elem "AuthenticAMD" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null"))));

      # Enable firmware updates
      enableAllFirmware = true;
      enableRedistributableFirmware = true;

      # Bluetooth support
      bluetooth = lib.mkIf config.hardware.autoDetect.peripherals.enable {
        enable = true;
        powerOnBoot = false;
        settings = {
          General = {
            Enable = "Source,Sink,Media,Socket";
            Experimental = true;
          };
        };
      };
    };

    # Services based on hardware (merged with udev below)
    services = lib.mkMerge [
      # Intel-specific services
      (lib.mkIf (config.hardware.autoDetect.cpu.enable && builtins.elem "GenuineIntel" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null")))) {
        thermald.enable = true;
        power-profiles-daemon.enable = false; # Conflicts with TLP
        tlp = {
          enable = true;
          settings = {
            CPU_SCALING_GOVERNOR_ON_AC = "performance";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
            CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
            CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
            CPU_MIN_PERF_ON_AC = 0;
            CPU_MAX_PERF_ON_AC = 100;
            CPU_MIN_PERF_ON_BAT = 0;
            CPU_MAX_PERF_ON_BAT = 50;
          };
        };
      })

      # AMD-specific services
      (lib.mkIf (config.hardware.autoDetect.cpu.enable && builtins.elem "AuthenticAMD" (lib.strings.splitString " " (builtins.readFile (if builtins.pathExists /proc/cpuinfo then /proc/cpuinfo else "/dev/null")))) {
        power-profiles-daemon.enable = true;
      })

      # Printing support
      (lib.mkIf config.hardware.autoDetect.peripherals.enable {
        printing = {
          enable = true;
          drivers = with pkgs; [
            gutenprint
            hplip
            brlaser
            samsung-unified-linux-driver
            splix
            cnijfilter2
          ];
        };

        # Scanner support
        # Note: hardware.sane configuration would go here if needed
      })

      # USB device management
      (lib.mkIf config.hardware.autoDetect.peripherals.enable {
        udisks2.enable = true;
        devmon.enable = true;
        gvfs.enable = true;
      })

      # Udev configuration
      {
        udev = {
          packages = lib.mkIf config.hardware.autoDetect.peripherals.enable (with pkgs; [
            usb-modeswitch
            android-udev-rules
          ]);

          extraRules = lib.mkMerge [
            # Storage optimization rules
            (lib.mkIf config.hardware.autoDetect.storage.enable ''
              # NVMe optimal settings
              ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
              ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/add_random}="0"
              ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rq_affinity}="2"
          
              # SSD optimal settings
              ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
              ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/add_random}="0"
              ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/rq_affinity}="2"
          
              # HDD optimal settings
              ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
              ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/add_random}="1"
            '')

            # Network optimization rules
            (lib.mkIf config.hardware.autoDetect.network.enable ''
              # Increase network device ring buffer
              ACTION=="add", SUBSYSTEM=="net", KERNEL=="eth*", RUN+="${pkgs.ethtool}/bin/ethtool -G $name rx 4096 tx 4096"
              ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="${pkgs.iw}/bin/iw dev $name set power_save off"
            '')

            # USB autosuspend for better power management
            (lib.mkIf config.hardware.autoDetect.peripherals.enable ''
              # Disable USB autosuspend for input devices
              ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="*", ATTR{idProduct}=="*", TEST=="authorized", ATTR{authorized}="1"
              ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usbhid", TEST=="power/control", ATTR{power/control}="on"
          
              # Enable autosuspend for other USB devices
              ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
            '')
          ];
        };
      }
    ];


    # Hardware tools
    environment.systemPackages = with pkgs; lib.mkMerge [
      # Basic hardware tools
      [
        pciutils
        usbutils
        lshw
        hwinfo
        dmidecode
      ]

      # CPU tools
      (lib.mkIf config.hardware.autoDetect.cpu.enable [
        cpufrequtils
        cpupower-gui
        turbostat
        i7z
        s-tui
        stress
      ])

      # Storage tools
      (lib.mkIf config.hardware.autoDetect.storage.enable [
        hdparm
        sdparm
        nvme-cli
        smartmontools
        gptfdisk
        parted
      ])

      # Network tools
      (lib.mkIf config.hardware.autoDetect.network.enable [
        ethtool
        iw
        wavemon
        wireless-tools
      ])

      # Peripheral tools
      (lib.mkIf config.hardware.autoDetect.peripherals.enable [
        bluez
        bluez-tools
        blueman
        usb-modeswitch
        usb-modeswitch-data
      ])
    ];

    # Firmware and drivers
    hardware.firmware = with pkgs; [
      linux-firmware
      sof-firmware
      alsa-firmware
      facetimehd-firmware
    ];
  };
}
