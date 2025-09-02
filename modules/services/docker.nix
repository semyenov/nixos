{ config, pkgs, ... }:

{
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

        # Performance
        max-concurrent-downloads = 10;
        max-concurrent-uploads = 5;
      };

      # Prune automatically
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" "--volumes" ];
      };
    };

    # Enable Podman as an alternative
    podman = {
      enable = true;
      dockerCompat = false; # Don't alias docker to podman
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # Container tools
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
    docker-credential-helpers
    lazydocker
    dive # Docker image explorer
    podman-compose
    podman-tui
    skopeo # Container image operations
    buildah # Build containers
  ];
}
