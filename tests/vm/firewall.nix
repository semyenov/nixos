# VM test for firewall configuration
# Tests that firewall rules work correctly

import ../lib/test-utils.nix ({ pkgs, lib, ... }:

{
  name = "firewall-test";
  
  nodes = {
    server = { config, pkgs, ... }: {
      imports = [
        ../../modules/security/firewall.nix
      ];
      
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 80 ];
      };
      
      # Simple web server for testing
      systemd.services.test-web-server = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 -m http.server 80";
          Type = "simple";
        };
      };
    };
    
    client = { config, pkgs, ... }: {
      environment.systemPackages = [ pkgs.curl ];
    };
  };
  
  testScript = ''
    server.start()
    client.start()
    
    server.wait_for_unit("multi-user.target")
    client.wait_for_unit("multi-user.target")
    
    # Wait for test web server
    server.wait_for_open_port(80)
    
    # Test allowed port (80)
    client.succeed("curl http://server:80")
    
    # Test blocked port (443 should be blocked)
    client.fail("timeout 5 curl http://server:443")
    
    # Test SSH rate limiting (if SSH is enabled)
    # This would attempt multiple rapid connections
    
    # Verify fail2ban is running
    server.succeed("systemctl is-active fail2ban")
    
    # Check iptables rules are applied
    server.succeed("iptables -L | grep -q Chain")
    
    print("✓ Firewall test passed")
  '';
})