{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.networking.firewall;
  centralConfig = import ../../lib/config.nix;
  utils = import ../../lib/module-utils.nix { inherit lib; };
  ports = centralConfig.network.ports;
in
{
  # Firewall configuration with centralized port definitions
  networking.firewall = {
    enable = true;

    # Allow specific TCP ports
    allowedTCPPorts = [
      # ports.services.ssh # SSH - commented out by default for security
      ports.services.http
      ports.services.https
    ] ++ optionals config.services.openssh.enable [ ports.services.ssh ]
    ++ optionals (config.environment.sessionVariables ? DEVELOPMENT) [
      ports.dev.default
      (ports.dev.default + 1) # 3001
      ports.dev.angular
      ports.dev.vite
      ports.dev.python
      ports.dev.altHttp
      ports.dev.php
    ];

    # Allow specific UDP ports
    allowedUDPPorts = [
      ports.services.wireguard
    ];

    # Allow specific port ranges
    allowedTCPPortRanges = [
      ports.dev.range # Development servers
      ports.dev.altRange # Alternative servers
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
        iptables -A INPUT -s ${centralConfig.network.docker.subnet} -j ACCEPT
        iptables -A INPUT -s ${centralConfig.network.docker.bridge} -j ACCEPT
      ''}
      
      # Enhanced rate limiting for SSH
      ${optionalString config.services.openssh.enable (
        let 
          sshLimit = centralConfig.security.rateLimit.ssh;
        in ''
          iptables -A INPUT -p tcp --dport ${toString ports.services.ssh} -m state --state NEW -m recent --set --name SSH --rsource
          iptables -A INPUT -p tcp --dport ${toString ports.services.ssh} -m state --state NEW -m recent --update --seconds ${toString sshLimit.seconds} --hitcount ${toString sshLimit.hitcount} --name SSH --rsource -j DROP
          iptables -A INPUT -p tcp --dport ${toString ports.services.ssh} -m state --state NEW -m recent --update --seconds ${toString sshLimit.longSeconds} --hitcount ${toString sshLimit.longHitcount} --name SSH --rsource -j DROP
        '')}
      
      # SYN flood protection
      ${let synFlood = centralConfig.security.rateLimit.synFlood; in ''
        iptables -N syn_flood
        iptables -A INPUT -p tcp --syn -j syn_flood
        iptables -A syn_flood -m limit --limit ${synFlood.limit} --limit-burst ${toString synFlood.burst} -j RETURN
        iptables -A syn_flood -j DROP
      ''}
      
      # Invalid packets
      iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
      
      # Port scan detection and blocking
      ${let portScan = centralConfig.security.rateLimit.portScan; in ''
        iptables -N port_scanning
        iptables -A port_scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit ${portScan.limit} --limit-burst ${toString portScan.burst} -j RETURN
        iptables -A port_scanning -j DROP
      ''}
    '';

    extraStopCommands = ''
      # Clean up Docker rules
      ${optionalString config.virtualisation.docker.enable ''
        iptables -D INPUT -s ${centralConfig.network.docker.subnet} -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -s ${centralConfig.network.docker.bridge} -j ACCEPT 2>/dev/null || true
      ''}
      
      # Clean up SSH rate limiting
      ${optionalString config.services.openssh.enable (
        let 
          sshLimit = centralConfig.security.rateLimit.ssh;
        in ''
          iptables -D INPUT -p tcp --dport ${toString ports.services.ssh} -m state --state NEW -m recent --set --name SSH --rsource 2>/dev/null || true
          iptables -D INPUT -p tcp --dport ${toString ports.services.ssh} -m state --state NEW -m recent --update --seconds ${toString sshLimit.seconds} --hitcount ${toString sshLimit.hitcount} --name SSH --rsource -j DROP 2>/dev/null || true
          iptables -D INPUT -p tcp --dport ${toString ports.services.ssh} -m state --state NEW -m recent --update --seconds ${toString sshLimit.longSeconds} --hitcount ${toString sshLimit.longHitcount} --name SSH --rsource -j DROP 2>/dev/null || true
        '')}
      
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

    maxretry = centralConfig.security.fail2ban.maxRetry;
    bantime = centralConfig.security.fail2ban.banTime;
    bantime-increment = {
      enable = true;
      factor = centralConfig.security.fail2ban.banFactor;
      maxtime = centralConfig.security.fail2ban.maxBanTime;
    };

    ignoreIP = centralConfig.network.privateRanges;

    jails = {
      # SSH jail is enabled by default with fail2ban
      # We can override settings if needed
      sshd.settings = {
        enabled = true;
        port = ports.services.ssh;
        filter = "sshd";
        maxretry = centralConfig.security.fail2ban.maxRetry;
        findtime = centralConfig.security.fail2ban.findTime;
        bantime = 3600; # 1 hour for SSH specifically
      };
    };
  };

  # Security packages
  environment.systemPackages = with pkgs; [
    iptables
    nftables
    fail2ban
  ];

  # Network-specific hardening (non-overlapping with hardening.nix)
  boot.kernel.sysctl = {
    # Network hardening
    "net.ipv4.conf.all.rp_filter" = mkDefault 1;
    "net.ipv4.conf.default.rp_filter" = mkDefault 1;
    "net.ipv4.conf.all.accept_source_route" = mkDefault 0;
    "net.ipv4.conf.default.accept_source_route" = mkDefault 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = mkDefault 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = mkDefault 1;
    "net.ipv4.conf.all.log_martians" = mkDefault 1;
    "net.ipv4.conf.default.log_martians" = mkDefault 1;
    "net.ipv4.conf.all.accept_redirects" = mkDefault 0;
    "net.ipv4.conf.default.accept_redirects" = mkDefault 0;
    "net.ipv6.conf.all.accept_redirects" = mkDefault 0;
    "net.ipv6.conf.default.accept_redirects" = mkDefault 0;
  };

  # Note: General kernel hardening is now handled by modules/security/hardening.nix
  # Enable it with: security.hardening.enable = true;
}
