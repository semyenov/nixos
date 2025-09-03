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
            ./modules/core

            # Hardware modules (Priority: 90)
            ./modules/hardware

            # System modules (Priority: 85)
            ./modules/system

            # Security modules (Priority: 80)
            ./modules/security

            # Service modules (Priority: 70)
            ./modules/services

            # Desktop modules (Priority: 60)
            ./modules/desktop

            # Development modules (Priority: 40)
            ./modules/development

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
              echo "Available shells: nixos, web, systems, ops, mobile"
              echo "Run 'nix develop .#<name>' to enter specialized environment"
            '';
          };
        });

      formatter = forAllSystems (system:
        (pkgsFor system).nixpkgs-fmt
      );

      # VM Tests (only available on Linux systems)
      checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
        let
          pkgs = pkgsFor system;
          lib = pkgs.lib;
          testUtils = import ./tests/lib/test-utils.nix { inherit pkgs lib; };
          vmTests = {
            vm-backup = testUtils (import ./tests/vm/backup.nix);
            vm-firewall = testUtils (import ./tests/vm/firewall.nix);
            vm-monitoring = testUtils (import ./tests/vm/monitoring.nix);
            vm-performance = testUtils (import ./tests/vm/performance.nix);
            vm-v2ray-secrets = testUtils (import ./tests/vm/v2ray-secrets.nix);
          };
        in
        vmTests
      );
    };
}
