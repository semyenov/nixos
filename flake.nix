{
  description = "NixOS configuration with Home Manager";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware configuration for common hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nixos-hardware, ... }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      # NixOS configuration entrypoint
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs; };

          modules = [
            # Main configuration
            ./hosts/nixos/configuration.nix

            # Hardware configuration
            ./hosts/nixos/hardware-configuration.nix

            # Modules
            ./modules/core/boot.nix
            ./modules/core/nix.nix
            ./modules/hardware/nvidia.nix
            ./modules/desktop/gnome.nix
            ./modules/services/networking.nix
            ./modules/services/audio.nix
            ./modules/services/docker.nix
            ./modules/services/v2ray.nix
            ./modules/services/v2ray-sops.nix
            ./modules/services/backup-simple.nix
            ./modules/services/monitoring.nix
            ./modules/development/typescript.nix
            ./modules/development/tools.nix
            ./modules/hardware/auto-detect.nix
            ./modules/security/firewall.nix
            ./modules/system/optimization.nix

            # Home Manager
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup"; # Automatically backup conflicting files
              home-manager.users.semyenov = import ./users/semyenov/home.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }

            # Secrets management
            sops-nix.nixosModules.sops
            ./modules/security/sops.nix
          ];
        };
      };

      # Development shells
      devShells.${system} = let
        shells = import ./shells.nix { inherit pkgs; };
      in shells // {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nil
            statix
            deadnix
            sops
            age
            ssh-to-age
          ];

          shellHook = ''
            echo "NixOS development environment"
            echo "Commands:"
            echo "  nixos-rebuild switch --flake .#nixos"
            echo "  nix flake update"
            echo "  nixpkgs-fmt ."
          '';
        };
      };
    };
}
