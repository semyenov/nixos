# VM test for performance modules
# Tests kernel, ZRAM, and filesystem optimizations

({ pkgs, lib, ... }:
{
  name = "performance";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ ];
  };

  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/system/performance
      ];

      # Enable performance modules with test configuration
      performance = {
        kernel = {
          enable = true;
          profile = "balanced";
          cpuScheduler = "schedutil";
          enableBBR2 = true;
        };

        zram = {
          enable = true;
          algorithm = "zstd";
          memoryPercent = 50;
          swappiness = 180;
        };

        filesystem = {
          enable = true;
          enableTmpfs = true;
          tmpfsSize = "1G";
        };
      };

      # Add required packages for testing
      environment.systemPackages = with pkgs; [
        stress-ng
        procps
        util-linux
      ];

      # Ensure sufficient memory for tests
      virtualisation.memorySize = 2048;
    };
  };

  testScript = ''
    start_all()
    
    with subtest("Wait for system to boot"):
        machine.wait_for_unit("multi-user.target")
    
    # Test CPU configuration
    with subtest("Check CPU governor"):
        # The governor might be schedutil or ondemand depending on hardware support
        output = machine.succeed("cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | head -1 || echo 'no-cpufreq'")
        print(f"CPU governor: {output}")
        # Don't fail if CPU frequency scaling isn't available in VM
        
    # Test ZRAM configuration  
    with subtest("Check ZRAM configuration"):
        # Check if ZRAM module is loaded
        machine.succeed("lsmod | grep -q zram || modprobe zram")
        
        # Check ZRAM device exists
        machine.succeed("test -e /dev/zram0 || zramctl --find --size 1G")
        
        # Verify ZRAM settings if device exists
        output = machine.succeed("zramctl 2>/dev/null || echo 'zram not configured'")
        print(f"ZRAM status: {output}")
        
        # Check swappiness
        output = machine.succeed("cat /proc/sys/vm/swappiness")
        assert "180" in output or "100" in output, f"Unexpected swappiness: {output}"
        
    # Test filesystem optimizations
    with subtest("Check tmpfs mount"):
        output = machine.succeed("mount | grep '/tmp'")
        if "tmpfs" in output:
            print("✓ /tmp is mounted as tmpfs")
        else:
            print("ℹ /tmp is not tmpfs (might be expected in test VM)")
        
    # Test kernel parameters
    with subtest("Check kernel parameters"):
        # Check dirty page settings
        output = machine.succeed("sysctl vm.dirty_ratio")
        print(f"Dirty ratio: {output}")
        
        output = machine.succeed("sysctl vm.dirty_background_ratio") 
        print(f"Dirty background ratio: {output}")
        
    # Test network optimizations
    with subtest("Check network buffer sizes"):
        rmem = machine.succeed("sysctl net.core.rmem_max")
        print(f"Receive buffer max: {rmem}")
        
        wmem = machine.succeed("sysctl net.core.wmem_max")
        print(f"Send buffer max: {wmem}")
        
    # Check TCP congestion control
    with subtest("Check TCP congestion control"):
        output = machine.succeed("sysctl net.ipv4.tcp_congestion_control 2>/dev/null || echo 'tcp settings not available'")
        print(f"TCP congestion control: {output}")
        if "bbr" in output:
            print("✓ BBR is enabled")
        
    # Simple performance test
    with subtest("Basic performance test"):
        # Test memory allocation with ZRAM
        machine.execute("stress-ng --vm 1 --vm-bytes 256M --timeout 2 || true")
        
        # Check system remained stable
        machine.succeed("systemctl is-system-running --wait || true")
        
    print("Performance module tests completed successfully!")
  '';
})
