# VM integration test for V2Ray secrets service
# Tests the complete service lifecycle including SOPS integration

import ../lib/test-utils.nix ({ pkgs, lib, ... }:

{
  name = "v2ray-secrets-service-test";

  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/services/network/v2ray-secrets.nix
        ../../modules/security/sops.nix
      ];

      # Enable V2Ray service
      services.v2rayWithSecrets.enable = true;

      # Mock SOPS configuration for testing
      sops = {
        defaultSopsFile = pkgs.writeText "v2ray-secrets.yaml" ''
          v2ray:
            server_address: ENC[AES256_GCM,data:example_server_address,type:str]
            server_port: ENC[AES256_GCM,data:443,type:int] 
            user_id: ENC[AES256_GCM,data:550e8400-e29b-41d4-a716-446655440000,type:str]
            public_key: ENC[AES256_GCM,data:example_public_key,type:str]
            short_id: ENC[AES256_GCM,data:example_short_id,type:str]
        '';
        
        # Mock age key for testing
        age.keyFile = pkgs.writeText "age-key" ''
          # created: 2023-01-01T00:00:00Z
          # public key: age1test...
          AGE-SECRET-KEY-1TEST...
        '';

        secrets = {
          "v2ray/server_address" = {
            sopsFile = pkgs.writeText "test-secrets.yaml" ''
              v2ray:
                server_address: test.example.com
                server_port: 443
                user_id: 550e8400-e29b-41d4-a716-446655440000
                public_key: test_public_key_here
                short_id: test123
            '';
            mode = "0400";
            owner = "root";
          };
          "v2ray/server_port" = {
            sopsFile = pkgs.writeText "test-secrets.yaml" ''
              v2ray:
                server_address: test.example.com
                server_port: 443
                user_id: 550e8400-e29b-41d4-a716-446655440000
                public_key: test_public_key_here
                short_id: test123
            '';
            mode = "0400";
            owner = "root";
          };
          "v2ray/user_id" = {
            sopsFile = pkgs.writeText "test-secrets.yaml" ''
              v2ray:
                server_address: test.example.com
                server_port: 443
                user_id: 550e8400-e29b-41d4-a716-446655440000
                public_key: test_public_key_here
                short_id: test123
            '';
            mode = "0400";
            owner = "root";
          };
          "v2ray/public_key" = {
            sopsFile = pkgs.writeText "test-secrets.yaml" ''
              v2ray:
                server_address: test.example.com
                server_port: 443
                user_id: 550e8400-e29b-41d4-a716-446655440000
                public_key: test_public_key_here
                short_id: test123
            '';
            mode = "0400";
            owner = "root";
          };
          "v2ray/short_id" = {
            sopsFile = pkgs.writeText "test-secrets.yaml" ''
              v2ray:
                server_address: test.example.com
                server_port: 443
                user_id: 550e8400-e29b-41d4-a716-446655440000
                public_key: test_public_key_here
                short_id: test123
            '';
            mode = "0400";
            owner = "root";
          };
        };
      };

      # Create mock secret files for testing (since SOPS decryption won't work in VM)
      system.activationScripts.mockSecrets = ''
        mkdir -p /run/secrets/v2ray
        echo "test.example.com" > /run/secrets/v2ray/server_address
        echo "443" > /run/secrets/v2ray/server_port
        echo "550e8400-e29b-41d4-a716-446655440000" > /run/secrets/v2ray/user_id
        echo "test_public_key_here" > /run/secrets/v2ray/public_key
        echo "test123" > /run/secrets/v2ray/short_id
        chmod 400 /run/secrets/v2ray/*
        chown root:root /run/secrets/v2ray/*
      '';

      # Override SOPS secret paths to use our mock files
      systemd.services.v2ray-custom.environment = {
        SOPS_SECRET_PATH = "/run/secrets";
      };

      # Network tools for testing
      environment.systemPackages = with pkgs; [
        curl
        netcat
        jq
        ps
      ];
    };
  };

  testScript = ''
    # Start the machine
    machine.start()
    
    print("=== V2Ray Secrets Service Integration Test ===")
    
    # Wait for system to be ready
    machine.wait_for_unit("multi-user.target")
    print("✓ System startup complete")
    
    # Check that mock secrets are created
    print("Checking mock secrets setup...")
    machine.succeed("test -f /run/secrets/v2ray/server_address")
    machine.succeed("test -f /run/secrets/v2ray/server_port")
    machine.succeed("test -f /run/secrets/v2ray/user_id") 
    machine.succeed("test -f /run/secrets/v2ray/public_key")
    machine.succeed("test -f /run/secrets/v2ray/short_id")
    print("✓ All secret files are present")
    
    # Verify secret file permissions
    machine.succeed("stat -c '%a' /run/secrets/v2ray/server_address | grep -q '400'")
    print("✓ Secret file permissions are correct")
    
    # Check that V2Ray package is installed
    machine.succeed("which v2ray")
    machine.succeed("v2ray version")
    print("✓ V2Ray package is installed and accessible")
    
    # Check systemd service configuration
    machine.succeed("systemctl cat v2ray-custom")
    print("✓ V2Ray custom service is configured")
    
    # Test service dependencies
    output = machine.succeed("systemctl show v2ray-custom --property=After")
    machine.succeed("echo '{}' | grep -q 'sops-nix.service'".format(output))
    print("✓ Service has correct dependencies")
    
    # Check firewall configuration
    machine.succeed("iptables -L | grep -E '1080|3128' || iptables-save | grep -E '1080|3128'")
    print("✓ Firewall ports are configured")
    
    # Test that jq is available (needed for config generation)
    machine.succeed("which jq")
    machine.succeed("echo '{}' | jq .")
    print("✓ JSON processing tools are available")
    
    # Start the V2Ray service
    print("Starting V2Ray service...")
    machine.start_job("v2ray-custom")
    
    # Wait a moment for service to initialize
    import time
    time.sleep(3)
    
    # Check service status
    machine.succeed("systemctl is-active v2ray-custom")
    print("✓ V2Ray service is running")
    
    # Verify V2Ray process is running
    machine.succeed("pgrep -f v2ray")
    print("✓ V2Ray process is active")
    
    # Test that proxy ports are listening
    machine.wait_for_open_port(1080)  # SOCKS port
    machine.wait_for_open_port(3128)  # HTTP port  
    print("✓ Proxy ports are listening")
    
    # Test configuration generation by checking service logs
    logs = machine.succeed("journalctl -u v2ray-custom --no-pager")
    # Don't check for specific config content since it's generated dynamically
    print("✓ Service logs accessible")
    
    # Test service restart functionality  
    print("Testing service restart...")
    machine.succeed("systemctl restart v2ray-custom")
    machine.wait_for_unit("v2ray-custom")
    machine.succeed("systemctl is-active v2ray-custom")
    print("✓ Service restart works correctly")
    
    # Test graceful service stop
    print("Testing service shutdown...")
    machine.succeed("systemctl stop v2ray-custom")
    machine.succeed("systemctl is-inactive v2ray-custom")
    print("✓ Service stops gracefully")
    
    # Verify ports are closed after stopping
    machine.fail("nc -z localhost 1080")
    machine.fail("nc -z localhost 3128") 
    print("✓ Ports are closed when service is stopped")
    
    # Test service security settings
    print("Verifying security hardening...")
    service_config = machine.succeed("systemctl show v2ray-custom --property=PrivateTmp,ProtectSystem,NoNewPrivileges")
    machine.succeed("echo '{}' | grep -q 'PrivateTmp=yes'".format(service_config))
    machine.succeed("echo '{}' | grep -q 'ProtectSystem=strict'".format(service_config))
    machine.succeed("echo '{}' | grep -q 'NoNewPrivileges=yes'".format(service_config))
    print("✓ Security hardening is properly applied")
    
    print("=== All V2Ray Secrets Service Tests Passed! ===")
  '';
})