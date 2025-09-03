# VM Test Utilities
# Streamlined test infrastructure for NixOS VM tests

testConfig:

{ pkgs, lib, ... }@args:

let
  test = testConfig args;
in
{
  inherit (test) name testScript;

  nodes = lib.mapAttrs
    (_: config:
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
          boot.initrd.enable = false;

          # Test networking
          networking.useDHCP = false;
          networking.firewall.enable = lib.mkDefault false;

          # Fast logging
          services.journald.extraConfig = "Storage=volatile";
        }
        config
    )
    test.nodes;
}
