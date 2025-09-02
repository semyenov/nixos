# Language Module Index
# Programming language environments and toolchains
# Supports multiple languages with consistent configuration

{ config, pkgs, lib, ... }:

{
  imports = [
    ./typescript.nix # TypeScript/JavaScript development
    # Additional languages can be added here:
    # ./python.nix
    # ./rust.nix
    # ./go.nix
  ];
}

