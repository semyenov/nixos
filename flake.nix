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

            # Module imports using index files for better organization
            # Modules are loaded in priority order (higher priority = earlier loading)

            # Core modules (Priority: 100)
            ./modules/core/index.nix

            # Hardware modules (Priority: 90)
            ./modules/hardware/index.nix

            # System modules (Priority: 85)
            ./modules/system/index.nix

            # Security modules (Priority: 80)
            ./modules/security/index.nix

            # Service modules (Priority: 70)
            ./modules/services/index.nix

            # Desktop modules (Priority: 60)
            ./modules/desktop/index.nix

            # Development modules (Priority: 40)
            ./modules/development/index.nix

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
          default = if shells ? nixos then shells.nixos else
          pkgs.mkShell {
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
