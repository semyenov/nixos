# VM Test Utilities
# Streamlined test infrastructure for NixOS VM tests

{ pkgs, lib }:
testConfig:

let

  # Check if nixosTest is available (Linux systems)
  hasNixosTest = pkgs ? nixosTest && pkgs.stdenv.isLinux;
in

if hasNixosTest then
  pkgs.nixosTest
    (
      let
        test = testConfig { inherit pkgs lib; };
      in
      {
        inherit (test) name testScript;

        nodes = lib.mapAttrs
          (_: nodeConfig:
            # Check if nodeConfig is a function (standard nixosTest format)
            if lib.isFunction nodeConfig then
            # It's a function, so we wrap it to add our defaults
              { config, pkgs, ... }@args:
              lib.recursiveUpdate
                {
                  # Fast test configuration  
                  virtualisation = {
                    memorySize = 1024;
                    diskSize = 4096;
                    graphics = false;
                  };

                  # Minimal boot
                  boot.loader.grub.enable = false;

                  # Test networking
                  networking.useDHCP = false;
                  networking.firewall.enable = lib.mkDefault false;

                  # Fast logging
                  services.journald.extraConfig = "Storage=volatile";
                }
                (nodeConfig args)
            else
            # It's already a set, merge directly
              lib.recursiveUpdate
                {
                  # Fast test configuration  
                  virtualisation = {
                    memorySize = 1024;
                    diskSize = 4096;
                    graphics = false;
                  };

                  # Minimal boot
                  boot.loader.grub.enable = false;

                  # Test networking
                  networking.useDHCP = false;
                  networking.firewall.enable = lib.mkDefault false;

                  # Fast logging
                  services.journald.extraConfig = "Storage=volatile";
                }
                nodeConfig
          )
          test.nodes;
      }
    )
else
# Fallback for non-Linux systems - return a mock derivation
  let
    test = testConfig { inherit pkgs lib; };
    safeName = lib.replaceStrings [ "-" " " ] [ "_" "_" ] test.name;
  in
  pkgs.runCommand "vm-test-${safeName}-skipped" { } ''
    echo "VM test skipped on ${pkgs.stdenv.hostPlatform.system}" > $out
    echo "VM tests require Linux with KVM support" >> $out
    echo "Test would check: ${test.name}" >> $out
  ''
