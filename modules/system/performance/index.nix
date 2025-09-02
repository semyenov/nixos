# Performance Module Index
# Performance optimization modules for kernel, memory, and filesystem
# Provides different optimization profiles for various workloads

{ config, pkgs, lib, ... }:

{
  imports = [
    ./kernel.nix # Kernel performance tuning
    ./zram.nix # ZRAM compressed memory swap
    ./filesystem.nix # Filesystem optimizations
  ];

}
