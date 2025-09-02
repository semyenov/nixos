# Test utilities and helpers for NixOS VM tests

testConfig:

{ pkgs, lib, ... }@args:

let
  # Import the test configuration
  test = testConfig args;

  # Helper functions for common test patterns
  helpers = {
    # Wait for a service with timeout
    waitForService = machine: service: timeout: ''
      ${machine}.wait_for_unit("${service}", timeout=${toString timeout})
    '';

    # Check if a port is open
    checkPort = machine: port: ''
      ${machine}.wait_for_open_port(${toString port})
    '';

    # Run command and check output
    checkOutput = machine: command: expected: ''
      output = ${machine}.succeed("${command}")
      assert "${expected}" in output, f"Expected '${expected}' in output, got: {output}"
    '';

    # Create test file
    createTestFile = machine: path: content: ''
      ${machine}.succeed("echo '${content}' > ${path}")
    '';
  };

  # Common test configuration
  commonConfig = {
    # Speed up tests
    virtualisation = {
      memorySize = 1024;
      diskSize = 4096;
      graphics = false;
    };

    # Minimal boot time
    boot.loader.grub.enable = false;
    boot.initrd.enable = false;

    # Test-friendly networking
    networking.useDHCP = false;
    networking.firewall.enable = lib.mkDefault false;

    # Faster for tests
    services.journald.extraConfig = ''
      Storage=volatile
    '';
  };

in
{
  inherit (test) name testScript;

  nodes = lib.mapAttrs
    (name: config:
      lib.recursiveUpdate commonConfig config
    )
    test.nodes;

  # Make the test runnable
  driver = pkgs.nixosTest {
    inherit (test) name testScript;
    nodes = lib.mapAttrs
      (name: config:
        { imports = [ config commonConfig ]; }
      )
      test.nodes;
  };
}
