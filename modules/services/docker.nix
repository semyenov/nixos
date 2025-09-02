# Docker Module
# Container virtualization with profile-based configuration
# Supports minimal, development, and production profiles

{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.services.docker;

  profileConfigs = {
    minimal = {
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
      packages = with pkgs; [
        docker-compose
      ];
      daemon = {
        max-concurrent-downloads = 3;
        max-concurrent-uploads = 2;
      };
    };

    development = {
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" "--volumes" ];
      };
      packages = with pkgs; [
        docker-compose
        docker-buildx
        docker-credential-helpers
        lazydocker
        dive # Docker image explorer
        podman-compose
        podman-tui
      ];
      daemon = {
        max-concurrent-downloads = 10;
        max-concurrent-uploads = 5;
      };
    };

    production = {
      autoPrune = {
        enable = true;
        dates = "daily";
        flags = [ "--all" "--volumes" "--filter" "until=48h" ];
      };
      packages = with pkgs; [
        docker-compose
        docker-buildx
        skopeo # Container image operations
        buildah # Build containers
      ];
      daemon = {
        max-concurrent-downloads = 6;
        max-concurrent-uploads = 3;
      };
    };
  };

  currentProfile = profileConfigs.${cfg.profile};
in
{
  options.services.docker = {
    enable = mkEnableOption "Docker container virtualization";

    profile = mkOption {
      type = types.enum [ "minimal" "development" "production" ];
      default = "minimal";
      description = ''
        Docker configuration profile:
        - minimal: Basic Docker with minimal packages
        - development: Full development environment with extra tools
        - production: Production-optimized with security focus
      '';
    };

    enablePodman = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Podman as Docker alternative";
    };
  };

  config = mkIf cfg.enable {
    virtualisation = {
      docker = {
        enable = true;
        enableOnBoot = true;

        # Storage configuration
        storageDriver = "overlay2";

        # Docker daemon configuration
        daemon.settings = {
          # Enable BuildKit for better build performance
          features = {
            buildkit = true;
          };

          # Logging
          log-driver = "json-file";
          log-opts = {
            max-size = "10m";
            max-file = "3";
          };

          # Network configuration
          default-address-pools = [
            {
              base = "172.30.0.0/16";
              size = 24;
            }
          ];

          # Security
          live-restore = true;
          userland-proxy = false;

          # Profile-based performance settings
          inherit (currentProfile.daemon) max-concurrent-downloads max-concurrent-uploads;
        };

        # Profile-based auto-pruning
        autoPrune = currentProfile.autoPrune;
      };

      # Optional Podman support
      podman = mkIf cfg.enablePodman {
        enable = true;
        dockerCompat = false; # Don't alias docker to podman
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    # Profile-based container tools
    environment.systemPackages = currentProfile.packages;
  };
}
