# Services Module Index
# Central import for all service modules

{ config, pkgs, lib, ... }:

{
  imports = [
    ./audio.nix
    ./docker.nix
    ./network
    ./system
  ];
}