# Desktop Module Index  
# Desktop environment configuration
# Manages display managers and desktop environments

{ config, pkgs, lib, ... }:

{
  imports = [
    ./gnome.nix # GNOME desktop environment
  ];
}