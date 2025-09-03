# Server Profile  
# Production server configuration using base profile system

{ config, pkgs, lib, ... }:

{
  imports = [
    (import ./base.nix { inherit config pkgs lib; profileType = "server"; })
  ];

  # Headless server configuration
  boot.kernelParams = [ "console=ttyS0" "console=tty0" ];

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = false;
    };
    extraConfig = ''
      ClientAliveInterval 60
      ClientAliveCountMax 3
    '';
  };

  # Server-specific packages
  environment.systemPackages = with pkgs; [
    # System administration
    tmux
    screen

    # Monitoring
    iotop
    nethogs

    # Server utilities
    rsync
    unzip

    # Network tools
    tcpdump
    netcat
    socat
  ];

  # Server-specific services
  services.fail2ban.enable = true;

  # Disable unnecessary services
  services.avahi.enable = false;
  services.printing.enable = false;
  services.flatpak.enable = false;
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = false;

  # Server optimizations  
  boot.kernel.sysctl = {
    # Network optimizations
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;

    # File handle limits
    "fs.file-max" = 2097152;
  };

  # Logrotate for server logs
  services.logrotate.enable = true;

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    randomizedDelaySec = "45min";
    allowReboot = false; # Manual reboot control
  };
}
