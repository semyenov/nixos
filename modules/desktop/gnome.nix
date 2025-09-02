{ config, pkgs, lib, ... }:

{
  services.xserver = {
    enable = true;

    # Display manager
    displayManager = {
      gdm = {
        enable = true;
        wayland = true; # Enable Wayland support
      };
    };

    # Desktop environment
    desktopManager.gnome = {
      enable = true;
    };

    # Keyboard configuration
    xkb = {
      layout = "us,ru";
      variant = "";
      options = "grp:alt_shift_toggle,caps:escape"; # Alt+Shift to switch, Caps as Escape
    };

    # Touchpad support is now under services.libinput
  };

  # Touchpad configuration
  services.libinput.enable = true;

  # GNOME-specific services
  services = {
    # Enable GNOME keyring
    gnome.gnome-keyring.enable = true;

    # Enable GVfs for mounting
    gvfs.enable = true;

    # Enable thumbnail service
    tumbler.enable = true;

    # Disable some GNOME apps
    gnome.localsearch.enable = false;
    gnome.tinysparql.enable = false;
  };

  # Remove default GNOME packages
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany # GNOME Web browser
    geary # Email client
    totem # Video player
    tali # Poker game
    iagno # Go game
    hitori # Sudoku game
    atomix # Puzzle game
    yelp # Help viewer
    gnome-music
    gnome-characters
    gnome-contacts
    gnome-initial-setup
  ];

  # Additional GNOME packages
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    dconf-editor

    # GNOME extensions
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.vitals
    gnomeExtensions.caffeine
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.rocketbar

    # Themes
    adwaita-icon-theme
    papirus-icon-theme

    # File manager plugins
    nautilus-python
  ];

  # QT theme
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };
}
