{ config, pkgs, ... }:

{
  nix = {
    # Enable flakes and new command
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # Optimize store automatically
      auto-optimise-store = true;

      # Users allowed to use Nix
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "@wheel" ];

      # Binary cache settings
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Parallel building
      max-jobs = "auto";
      cores = 0; # Use all available cores

      # Prevent disk space issues
      min-free = 1073741824; # 1GB
      max-free = 5368709120; # 5GB
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
    };

    # Store optimization
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };
}
