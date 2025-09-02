{ config, pkgs, lib, ... }:

{
  # Firewall configuration
  networking.firewall = {
    enable = true;

    # Allow specific TCP ports
    allowedTCPPorts = [
      22 # SSH (if needed externally)
      80 # HTTP
      443 # HTTPS
      3000 # Development server
      3001 # Development server
      4200 # Angular dev server
      5173 # Vite dev server
      8080 # Alternative HTTP
      8000 # Python dev server
      9000 # PHP dev server
    ];

    # Allow specific UDP ports
    allowedUDPPorts = [
      51820 # WireGuard
    ];

    # Allow specific port ranges
    allowedTCPPortRanges = [
      { from = 3000; to = 3010; } # Development servers
      { from = 8000; to = 8010; } # Alternative servers
    ];

    # Reject instead of drop
    rejectPackets = false;

    # Log refused packets
    logRefusedConnections = true;
    logRefusedPackets = false;
    logRefusedUnicastsOnly = true;

    # Extra commands
    extraCommands = ''
      # Allow Docker networks
      iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
      
      # Rate limiting for SSH
      iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
      iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
    '';

    extraStopCommands = ''
      iptables -D INPUT -s 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -p tcp --dport 22 -m state --state NEW -m recent --set 2>/dev/null || true
      iptables -D INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP 2>/dev/null || true
    '';
  };

  # Fail2ban for additional protection
  services.fail2ban = {
    enable = true;

    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      factor = "2";
      maxtime = "168h"; # 1 week
    };

    ignoreIP = [
      "127.0.0.0/8"
      "::1"
      "192.168.0.0/16"
      "10.0.0.0/8"
      "172.16.0.0/12"
    ];

    jails = {
      # SSH jail is enabled by default with fail2ban
      # We can override settings if needed
      sshd.settings = {
        enabled = true;
        port = 22;
        filter = "sshd";
        maxretry = 3;
        findtime = 600;
        bantime = 3600;
      };
    };
  };

  # Security packages
  environment.systemPackages = with pkgs; [
    iptables
    nftables
    fail2ban
  ];

  # Kernel hardening
  boot.kernel.sysctl = {
    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # Kernel hardening
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;

    # File system hardening
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
  };
}
