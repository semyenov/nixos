# Desktop Module Index
# Manages desktop environment and GUI-related configuration
# Includes display managers, window managers, and desktop environments

{ config, pkgs, lib, ... }:

{
  imports = [
    ./gnome.nix # GNOME desktop environment
  ];

}
