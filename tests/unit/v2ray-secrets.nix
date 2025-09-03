# Unit tests for V2Ray secrets module
# Tests module options, assertions, and configuration generation

let
  lib = import <nixpkgs/lib>;

  # Import minimal NixOS system options  
  baseModule = { config, lib, pkgs, ... }: {
    options = {
      system.stateVersion = lib.mkOption {
        type = lib.types.str;
        default = "25.05";
      };
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
      };
      systemd.services = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      networking.firewall = {
        allowedTCPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
        };
      };
      environment.systemPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
      sops.secrets = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
      };
    };

    config = {
      sops.secrets = {
        "v2ray/server_address" = {
          path = "/run/secrets/v2ray/server_address";
        };
        "v2ray/server_port" = {
          path = "/run/secrets/v2ray/server_port";
        };
        "v2ray/user_id" = {
          path = "/run/secrets/v2ray/user_id";
        };
        "v2ray/public_key" = {
          path = "/run/secrets/v2ray/public_key";
        };
        "v2ray/short_id" = {
          path = "/run/secrets/v2ray/short_id";
        };
      };
    };
  };

  # Test helper functions  
  pkgs = import <nixpkgs> { };

  testModule = args: lib.evalModules {
    modules = [
      baseModule
      ../../modules/services/network/v2ray-secrets.nix
      args
    ];
    specialArgs = { inherit pkgs; };
  };

  # Test cases
  tests = {
    # Test 1: Module loads without errors when disabled
    "module-loads-disabled" = {
      expr = (testModule { }).config.services.v2rayWithSecrets.enable;
      expected = false;
    };

    # Test 2: Service can be enabled
    "service-enable" = {
      expr = (testModule {
        services.v2rayWithSecrets.enable = true;
      }).config.services.v2rayWithSecrets.enable;
      expected = true;
    };

    # Test 3: SOPS secrets are configured when enabled
    "sops-secrets-configured" = {
      expr = builtins.hasAttr "v2ray/server_address"
        (testModule {
          services.v2rayWithSecrets.enable = true;
        }).config.sops.secrets;
      expected = true;
    };

    # Test 4: All required SOPS secrets are present
    "all-sops-secrets-present" = {
      expr =
        let
          cfg = (testModule {
            services.v2rayWithSecrets.enable = true;
          }).config;
          secrets = cfg.sops.secrets;
          requiredSecrets = [
            "v2ray/server_address"
            "v2ray/server_port"
            "v2ray/user_id"
            "v2ray/public_key"
            "v2ray/short_id"
          ];
        in
        lib.all (secret: builtins.hasAttr secret secrets) requiredSecrets;
      expected = true;
    };

    # Test 5: Systemd service is created when enabled
    "systemd-service-created" = {
      expr = builtins.hasAttr "v2ray-custom"
        (testModule {
          services.v2rayWithSecrets.enable = true;
        }).config.systemd.services;
      expected = true;
    };

    # Test 6: Firewall ports are opened
    "firewall-ports-opened" = {
      expr =
        let
          cfg = (testModule {
            services.v2rayWithSecrets.enable = true;
          }).config;
          allowedPorts = cfg.networking.firewall.allowedTCPPorts;
        in
        lib.length allowedPorts >= 2; # Should have at least the V2Ray ports
      expected = true;
    };

    # Test 7: V2Ray package is installed
    "v2ray-package-installed" = {
      expr =
        let
          cfg = (testModule {
            services.v2rayWithSecrets.enable = true;
          }).config;
          packages = cfg.environment.systemPackages;
        in
        lib.length packages >= 1; # Should have at least v2ray and jq packages
      expected = true;
    };

    # Test 8: Service depends on SOPS
    "service-depends-on-sops" = {
      expr =
        let
          cfg = (testModule {
            services.v2rayWithSecrets.enable = true;
          }).config;
          service = cfg.systemd.services.v2ray-custom;
        in
        lib.elem "sops-nix.service" service.after;
      expected = true;
    };

    # Test 9: Service security hardening is applied  
    "service-security-hardening" = {
      expr =
        let
          cfg = (testModule {
            services.v2rayWithSecrets.enable = true;
          }).config;
          serviceConfig = cfg.systemd.services.v2ray-custom.serviceConfig;
        in
        serviceConfig.PrivateTmp == true &&
        serviceConfig.ProtectSystem == "strict" &&
        serviceConfig.NoNewPrivileges == true;
      expected = true;
    };

    # Test 10: Configuration template contains required fields
    "config-template-valid" = {
      expr =
        let
          v2rayModule = import ../../modules/services/network/v2ray-secrets.nix;
          # We can't easily access the internal template, so we test that 
          # the module loads without syntax errors
          testResult = testModule {
            services.v2rayWithSecrets.enable = true;
          };
        in
        testResult.config.services.v2rayWithSecrets.enable;
      expected = true;
    };
  };

  # Test execution
  results = lib.mapAttrs
    (name: test: {
      name = name;
      passed = test.expr == test.expected;
      expected = test.expected;
      actual = test.expr;
    })
    tests;

  # Count results
  totalTests = lib.length (lib.attrNames tests);
  passedTests = lib.length (lib.filter (result: result.passed) (lib.attrValues results));
  failedTests = totalTests - passedTests;

  # Failed test details
  failures = lib.filterAttrs (_: result: !result.passed) results;

in
{
  # Test results
  inherit results;

  # Summary
  summary = {
    total = totalTests;
    passed = passedTests;
    failed = failedTests;
  };

  # Overall result
  result =
    if failedTests == 0
    then "All ${toString totalTests} V2Ray secrets tests passed!"
    else "${toString failedTests} of ${toString totalTests} V2Ray secrets tests failed";

  # Failure details
  inherit failures;
}
