{ config, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    
    # NetworkManager for easy network configuration
    networkmanager = {
      enable = true;
      wifi = {
        backend = "iwd";  # Use iwd for better WiFi performance
        powersave = false;
      };
    };
    
    # Enable IPv6
    enableIPv6 = true;
    
    # DNS configuration
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
    
    # Use systemd-resolved
    resolvconf.enable = false;
  };
  
  # Enable systemd-resolved for better DNS management
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [
      "8.8.8.8"
      "8.8.4.4"
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
    ];
    extraConfig = ''
      DNSOverTLS=yes
    '';
  };
  
  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
    
    # Hardening
    extraConfig = ''
      Protocol 2
      ClientAliveInterval 300
      ClientAliveCountMax 2
      MaxAuthTries 3
      MaxSessions 10
      AllowGroups wheel
    '';
  };
  
  # Additional networking tools
  environment.systemPackages = with pkgs; [
    networkmanager-openvpn
    networkmanager-l2tp
    wireguard-tools
    iwd
    dig
    nmap
    traceroute
    whois
    nettools
    inetutils
  ];
}