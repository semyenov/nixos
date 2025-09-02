# Development Module Index
# Development tools and language support
# Provides comprehensive development environment setup

{ config, pkgs, lib, ... }:

{
  imports = [
    ./languages # Programming language support
    ./tools.nix # Development tools and utilities
  ];
}

