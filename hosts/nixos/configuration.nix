{ config, pkgs, inputs, ... }:

{
  imports = [
    # Hardware configuration in the same directory
    ./hardware-configuration.nix
  ];

  # ========================
  # LOCALIZATION
  # ========================

  # Timezone
  time.timeZone = "Europe/Moscow";

  # Locale settings
  i18n = {
    defaultLocale = "en_US.UTF-8";

    # Russian formatting while keeping English UI
    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "ru_RU.UTF-8";
    };
  };

  # ========================
  # USER CONFIGURATION
  # ========================

  users.users.semyenov = {
    isNormalUser = true;
    description = "Alexander Semyenov";

    # User groups
    extraGroups = [
      "networkmanager" # Network management
      "wheel" # sudo access
      "docker" # Docker without sudo
      "audio" # Audio devices
      "video" # Video devices
      "input" # Input devices
      "plugdev" # Removable devices
    ];

    # Enable shell
    shell = pkgs.zsh;
  };

  # Add semyenova user without root privileges
  users.users.semyenova = {
    isNormalUser = true;
    description = "Semyenova";

    # Basic groups only (no wheel = no sudo)
    extraGroups = [
      "networkmanager" # Network access
      "audio" # Audio devices
      "video" # Video devices
    ];

    # Set password after first boot with: sudo passwd semyenova
    # Or set initial password hash with mkpasswd -m sha-512
    # initialPassword = "changeme";  # Set initial password (change on first login)

    # Enable shell
    shell = pkgs.bash; # or pkgs.zsh if you prefer
  };

  # Enable ZSH
  programs.zsh.enable = true;

  # ========================
  # SYSTEM-WIDE PROGRAMS
  # ========================

  # System packages (minimal, most go to Home Manager)
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    nekoray
  ];

  # Firefox as system browser
  programs.firefox.enable = true;

  # ========================
  # SERVICES
  # ========================

  services = {
    # Printing support
    printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        hplip
      ];
    };

    # Enable CUPS for printing
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Enable flatpak
    flatpak.enable = true;

    # Enable geoclue2
    geoclue2.enable = true;

    # Enable accounts daemon
    accounts-daemon.enable = true;

    # Enable power profiles daemon
    power-profiles-daemon.enable = true;

    # V2Ray is configured via v2rayWithSecrets module when needed
    # v2ray.enable = true;  # Commented out - use services.v2rayWithSecrets.enable instead
  };

  # XDG portal for Flatpak
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ========================
  # SYSTEM VERSION
  # ========================

  # DO NOT CHANGE unless following migration guide
  system.stateVersion = "25.05";
}
