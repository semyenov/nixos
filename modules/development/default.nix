# Development Module Index
# Central import for all development modules

{ config, pkgs, lib, ... }:

{
  imports = [
    ./languages
    ./tools.nix
  ];
}

