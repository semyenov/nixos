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
      
      # Support multiple systems for development shells
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      
      # Helper to create outputs for all supported systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      
      # Helper to get pkgs for any system
      pkgsFor = system: import nixpkgs {
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
            ./modules/services/v2ray-secrets.nix
            ./modules/services/backup.nix
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

      # Development shells for all supported systems
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          shells = import ./shells.nix { inherit pkgs; };
        in
        shells // {
          # Default to the nixos configuration development shell
          default = shells.nixos or pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil
              statix
              deadnix
              sops
              age
              ssh-to-age
              go-task
            ];

            shellHook = ''
              echo "NixOS development environment"
              echo "Available shells: nixos, typescript, python, rust, go, cpp, database, datascience, devops, mobile, security"
              echo "Run 'task shell:<name>' or 'nix develop .#<name>'"
            '';
          };
        });

      formatter = forAllSystems (system:
        (pkgsFor system).nixpkgs-fmt
      );
    };
}
