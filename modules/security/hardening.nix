{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.security.hardening;
in
{
  options.security.hardening = {
    enable = mkEnableOption "enhanced security hardening";

    profile = mkOption {
      type = types.enum [ "minimal" "standard" "hardened" "paranoid" ];
      default = "standard";
      description = ''
        Security hardening profile:
        - minimal: Basic hardening, suitable for development
        - standard: Recommended for most systems
        - hardened: Strong security, may break some applications
        - paranoid: Maximum security, will break many applications
      '';
    };

    enableSystemdHardening = mkOption {
      type = types.bool;
      default = true;
      description = "Enable systemd service hardening";
    };

    enableKernelHardening = mkOption {
      type = types.bool;
      default = true;
      description = "Enable kernel security features";
    };

    enableAppArmor = mkOption {
      type = types.bool;
      default = false;
      description = "Enable AppArmor (experimental)";
    };

    enableAuditd = mkOption {
      type = types.bool;
      default = false;
      description = "Enable audit daemon for security monitoring";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Base hardening for all profiles
    {
      # Enable firewall by default
      networking.firewall.enable = mkDefault true;

      # Basic kernel hardening
      boot.kernel.sysctl = {
        # Core dumps
        "fs.suid_dumpable" = 0;

        # ASLR
        "kernel.randomize_va_space" = 2;

        # Hide kernel pointers
        "kernel.kptr_restrict" = mkDefault 1;

        # Restrict dmesg
        "kernel.dmesg_restrict" = mkDefault 1;

        # Protect hardlinks/symlinks
        "fs.protected_hardlinks" = 1;
        "fs.protected_symlinks" = 1;
        "fs.protected_regular" = mkDefault 1;
        "fs.protected_fifos" = mkDefault 1;
      };

      # Security packages
      environment.systemPackages = with pkgs; [
        lynis # Security auditing
        aide # Intrusion detection
        rkhunter # Rootkit hunter
      ] ++ optionals cfg.enableAuditd [
        audit
      ];
    }

    # Standard profile
    (mkIf (cfg.profile == "standard" || cfg.profile == "hardened" || cfg.profile == "paranoid") {
      boot.kernel.sysctl = {
        # BPF restrictions
        "kernel.unprivileged_bpf_disabled" = mkDefault 1;
        "net.core.bpf_jit_harden" = mkDefault 2;

        # Ptrace restrictions
        "kernel.yama.ptrace_scope" = mkDefault 1;

        # Performance events restrictions
        "kernel.perf_event_paranoid" = mkDefault 2;

        # Core pattern (disable core dumps to external programs)
        "kernel.core_pattern" = mkDefault "|/bin/false";
      };

      # Restrict kernel module loading
      boot.kernelParams = [ "modules.sig_enforce=1" ];
    })

    # Hardened profile
    (mkIf (cfg.profile == "hardened" || cfg.profile == "paranoid") {
      # Note: To use the hardened profile, import it at the system level
      # imports = [ <nixpkgs/nixos/modules/profiles/hardened.nix> ];

      boot.kernel.sysctl = {
        # Stricter restrictions
        "kernel.kptr_restrict" = 2;
        "kernel.yama.ptrace_scope" = 2;
        "kernel.perf_event_paranoid" = 3;
        "kernel.unprivileged_userns_clone" = 0;

        # JIT hardening
        "net.core.bpf_jit_harden" = 2;

        # Restrict kernel logs
        "kernel.printk" = "3 3 3 3";
      };

      # Additional boot parameters
      boot.kernelParams = [
        "slab_nomerge"
        "init_on_alloc=1"
        "init_on_free=1"
        "page_alloc.shuffle=1"
        "nohibernate"
      ] ++ optionals (cfg.profile == "paranoid") [
        "lockdown=confidentiality"
      ];
    })

    # Systemd service hardening
    (mkIf cfg.enableSystemdHardening {
      # Note: Service-specific hardening would be applied via overlays
      # or specific service configurations rather than globally
      # to avoid conflicts with existing service definitions

      # Example hardening that can be enabled per-service:
      # services.nginx.serviceConfig = {
      #   PrivateTmp = true;
      #   ProtectSystem = "strict";
      #   NoNewPrivileges = true;
      # };
    })

    # AppArmor configuration
    (mkIf cfg.enableAppArmor {
      security.apparmor.enable = true;
      services.dbus.apparmor = "enabled";
    })

    # Audit daemon
    (mkIf cfg.enableAuditd {
      security.auditd.enable = true;
      security.audit = {
        enable = true;
        backlogLimit = 8192;
        failureMode = "printk";
        rules = [
          "-w /etc/passwd -p wa -k passwd_changes"
          "-w /etc/shadow -p wa -k shadow_changes"
          "-w /etc/group -p wa -k group_changes"
          "-a exit,always -F arch=b64 -S execve -k exec"
          "-w /var/log/sudo.log -p wa -k sudo_log_changes"
        ];
      };
    })

    # Additional security tools
    {
      # Lynis security auditing
      systemd.services.lynis-audit = mkIf (cfg.profile == "hardened" || cfg.profile == "paranoid") {
        description = "Lynis security audit";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.lynis}/bin/lynis audit system --quick";
        };
      };

      systemd.timers.lynis-audit = mkIf (cfg.profile == "hardened" || cfg.profile == "paranoid") {
        description = "Weekly Lynis security audit";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
      };

      # AIDE intrusion detection (requires separate setup)
      # Note: AIDE is not available as a NixOS service by default
      # You would need to set it up manually or create a custom module
    }
  ]);
}
