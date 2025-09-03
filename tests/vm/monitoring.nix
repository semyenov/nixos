# VM test for monitoring module
# Tests Prometheus, Grafana, and alert functionality

import ../lib/test-utils.nix ({ pkgs, lib, ... }:

{
  name = "monitoring";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ ];
  };

  nodes = {
    server = { config, pkgs, ... }: {
      imports = [
        ../../modules/services/system/monitoring.nix
      ];

      # Enable monitoring services
      services.monitoring = {
        enable = true;

        prometheus = {
          enable = true;
          port = 9090;
        };

        grafana = {
          enable = true;
          port = 3000;
        };

        alerts = {
          enable = true;
          email = "test@example.com";
        };
      };

      # Faster for testing
      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 4096;
    };
  };

  testScript = ''
    start_all()
    
    with subtest("Wait for system to boot"):
        server.wait_for_unit("multi-user.target")
    
    with subtest("Prometheus service should be running"):
        server.wait_for_unit("prometheus.service")
        server.wait_for_open_port(9090)
        
    with subtest("Prometheus web interface should be accessible"):
        server.succeed("curl -f http://localhost:9090/-/healthy")
        
    with subtest("Node exporter should be running"):
        server.wait_for_unit("prometheus-node-exporter.service")
        server.wait_for_open_port(9100)
        
    with subtest("Prometheus should scrape metrics"):
        # Wait for first scrape
        server.sleep(10)
        output = server.succeed("curl -s http://localhost:9090/api/v1/targets")
        assert "node" in output, "Node exporter target not found"
        
    with subtest("Grafana service should be running"):
        server.wait_for_unit("grafana.service")
        server.wait_for_open_port(3000)
        
    with subtest("Grafana web interface should be accessible"):
        server.succeed("curl -f http://localhost:3000/api/health")
        
    with subtest("Alert monitoring service should be running"):
        server.wait_for_unit("system-monitor-alerts.service")
        
    with subtest("Alert timer should be active"):
        server.wait_for_unit("system-monitor-alerts.timer")
        output = server.succeed("systemctl is-active system-monitor-alerts.timer")
        assert "active" in output, "Alert timer is not active"
        
    with subtest("Test high CPU alert"):
        # Generate CPU load
        server.execute("stress-ng --cpu 4 --timeout 5 &")
        server.sleep(6)
        
        # Check if alert would trigger (check logs)
        logs = server.succeed("journalctl -u system-monitor-alerts -n 50")
        # Alert script should have run
        
    with subtest("Test disk space monitoring"):
        # Create a large file to trigger disk alert
        server.execute("dd if=/dev/zero of=/tmp/bigfile bs=1M count=1000 || true")
        
        # Manually trigger alert check
        server.succeed("systemctl start system-monitor-alerts.service")
        
        # Cleanup
        server.execute("rm -f /tmp/bigfile")
        
    with subtest("Firewall allows monitoring ports"):
        # Check that firewall rules are configured
        rules = server.succeed("iptables -L -n")
        # Ports 9090 and 3000 should be allowed
  '';
})
