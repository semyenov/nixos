# VM test for backup service
# Tests that the backup service works correctly

({ pkgs, lib, ... }:

{
  name = "backup-service-test";

  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/services/system/backup.nix
      ];

      # Enable backup service with test configuration
      services.backup = {
        enable = true;
        repository = "/tmp/backup-test";
        paths = [ "/tmp/test-data" ];
        schedule = "minutely"; # For testing
      };

      # Create test data
      system.activationScripts.testData = ''
        mkdir -p /tmp/test-data
        echo "test content" > /tmp/test-data/test.txt
        echo "important data" > /tmp/test-data/important.txt
      '';
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    
    # Wait for backup repository initialization
    machine.wait_until_succeeds("test -d /tmp/backup-test")
    
    # Trigger backup manually
    machine.succeed("systemctl start borgbackup-job-system-backup.service")
    
    # Wait for backup to complete
    machine.wait_until_succeeds("systemctl is-active borgbackup-job-system-backup.service || true")
    
    # Verify backup was created
    machine.succeed("borg list /tmp/backup-test")
    
    # Test restoration
    machine.succeed("rm -rf /tmp/test-data")
    machine.succeed("cd /tmp && borg extract /tmp/backup-test::$(borg list --short /tmp/backup-test | head -1)")
    
    # Verify restored data
    machine.succeed("test -f /tmp/test-data/test.txt")
    machine.succeed("grep 'test content' /tmp/test-data/test.txt")
    machine.succeed("grep 'important data' /tmp/test-data/important.txt")
    
    print("✓ Backup service test passed")
  '';
})
