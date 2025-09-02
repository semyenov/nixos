{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.networking.firewall;
in
{
  # Firewall configuration
  networking.firewall = {
    enable = true;

    # Allow specific TCP ports
    allowedTCPPorts = [
      # 22 # SSH - commented out by default for security
      80 # HTTP
      443 # HTTPS
    ] ++ optionals config.services.openssh.enable [ 22 ]
    ++ optionals (config.environment.sessionVariables ? DEVELOPMENT) [
      3000 # Development server
      3001 # Development server 
      4200 # Angular dev server
      5173 # Vite dev server
      8000 # Python dev server
      8080 # Alternative HTTP
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

    # Extra commands with improved security rules
    extraCommands = ''
      # Allow Docker networks only if Docker is enabled
      ${optionalString config.virtualisation.docker.enable ''
        iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
        iptables -A INPUT -s 172.17.0.0/16 -j ACCEPT
      ''}
      
      # Enhanced rate limiting for SSH
      ${optionalString config.services.openssh.enable ''
        iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH --rsource
        iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH --rsource -j DROP
        iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 300 --hitcount 10 --name SSH --rsource -j DROP
      ''}
      
      # SYN flood protection
      iptables -N syn_flood
      iptables -A INPUT -p tcp --syn -j syn_flood
      iptables -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
      iptables -A syn_flood -j DROP
      
      # Invalid packets
      iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
      
      # Port scan detection and blocking
      iptables -N port_scanning
      iptables -A port_scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN
      iptables -A port_scanning -j DROP
    '';

    extraStopCommands = ''
      # Clean up Docker rules
      ${optionalString config.virtualisation.docker.enable ''
        iptables -D INPUT -s 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -s 172.17.0.0/16 -j ACCEPT 2>/dev/null || true
      ''}
      
      # Clean up SSH rate limiting
      ${optionalString config.services.openssh.enable ''
        iptables -D INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH --rsource 2>/dev/null || true
        iptables -D INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH --rsource -j DROP 2>/dev/null || true
        iptables -D INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 300 --hitcount 10 --name SSH --rsource -j DROP 2>/dev/null || true
      ''}
      
      # Clean up custom chains
      iptables -F syn_flood 2>/dev/null || true
      iptables -X syn_flood 2>/dev/null || true
      iptables -F port_scanning 2>/dev/null || true
      iptables -X port_scanning 2>/dev/null || true
      iptables -D INPUT -p tcp --syn -j syn_flood 2>/dev/null || true
      iptables -D INPUT -m conntrack --ctstate INVALID -j DROP 2>/dev/null || true
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

  # Enhanced kernel hardening
  boot.kernel.sysctl = {
    # Core dumps
    "fs.suid_dumpable" = 0;

    # Address space layout randomization
    "kernel.randomize_va_space" = 2;

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
    "kernel.unprivileged_userns_clone" = mkDefault 0; # May break some containers
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.panic" = 10; # Reboot after 10 seconds on kernel panic
    "kernel.panic_on_oops" = 1; # Panic on oops
    "kernel.modules_disabled" = mkDefault 0; # Set to 1 to disable module loading after boot

    # File system hardening
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
  };
}
