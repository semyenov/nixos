# VM test for performance modules
# Tests kernel, ZRAM, and filesystem optimizations

{ pkgs, lib, ... }:

let
  testUtils = import ../lib/test-utils.nix { inherit pkgs lib; };
in
{
  name = "performance";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ ];
  };

  nodes = {
    balanced = { config, pkgs, ... }: {
      imports = [
        ../../modules/system/performance/index.nix
        testUtils.minimalConfig
      ];

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

      virtualisation.memorySize = 2048;
    };

    performance = { config, pkgs, ... }: {
      imports = [
        ../../modules/system/performance/index.nix
        testUtils.minimalConfig
      ];

      performance = {
        kernel = {
          enable = true;
          profile = "performance";
          cpuScheduler = "performance";
          enableBBR2 = true;
          transparentHugepages = "always";
        };

        zram = {
          enable = true;
          algorithm = "lz4"; # Faster for performance
          memoryPercent = 25;
          swappiness = 100;
        };
      };

      virtualisation.memorySize = 2048;
    };
  };

  testScript = ''
    start_all()
    
    with subtest("Wait for systems to boot"):
        balanced.wait_for_unit("multi-user.target")
        performance.wait_for_unit("multi-user.target")
    
    # Test balanced node
    with subtest("Balanced: Check CPU governor"):
        output = balanced.succeed("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
        assert "schedutil" in output or "ondemand" in output, f"Wrong CPU governor: {output}"
        
    with subtest("Balanced: Check ZRAM configuration"):
        balanced.succeed("zramctl | grep -q zstd")
        output = balanced.succeed("cat /proc/sys/vm/swappiness")
        assert "180" in output, f"Wrong swappiness: {output}"
        
    with subtest("Balanced: Check ZRAM is active"):
        output = balanced.succeed("swapon --show")
        assert "/dev/zram0" in output, "ZRAM swap not active"
        
    with subtest("Balanced: Check kernel parameters"):
        output = balanced.succeed("sysctl vm.dirty_expire_centisecs")
        # Should be set to default value from config
        
    with subtest("Balanced: Check tmpfs mount"):
        output = balanced.succeed("mount | grep /tmp")
        assert "tmpfs" in output, "/tmp is not mounted as tmpfs"
        
    # Test performance node
    with subtest("Performance: Check CPU governor"):
        output = performance.succeed("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
        assert "performance" in output, f"Wrong CPU governor: {output}"
        
    with subtest("Performance: Check ZRAM uses lz4"):
        performance.succeed("zramctl | grep -q lz4")
        
    with subtest("Performance: Check transparent hugepages"):
        output = performance.succeed("cat /sys/kernel/mm/transparent_hugepage/enabled")
        assert "[always]" in output, f"THP not set to always: {output}"
        
    with subtest("Performance: Check network buffer sizes"):
        rmem = performance.succeed("sysctl net.core.rmem_max")
        assert "67108864" in rmem, f"Wrong rmem_max: {rmem}"
        
        wmem = performance.succeed("sysctl net.core.wmem_max")
        assert "67108864" in wmem, f"Wrong wmem_max: {wmem}"
        
    with subtest("Performance: Check TCP congestion control"):
        output = performance.succeed("sysctl net.ipv4.tcp_congestion_control")
        assert "bbr" in output, f"BBR not enabled: {output}"
        
    with subtest("Performance: Memory pressure test"):
        # Allocate memory to test ZRAM compression
        performance.execute("stress-ng --vm 1 --vm-bytes 75% --timeout 5 || true")
        
        # Check ZRAM stats
        output = performance.succeed("zramctl")
        # Should show compression ratio
        
    with subtest("Compare performance profiles"):
        # Simple benchmark to show difference
        balanced_time = balanced.succeed(
            "time -p sh -c 'for i in $(seq 1 1000); do echo $i > /dev/null; done' 2>&1 | grep real | awk '{print $2}'"
        ).strip()
        
        performance_time = performance.succeed(
            "time -p sh -c 'for i in $(seq 1 1000); do echo $i > /dev/null; done' 2>&1 | grep real | awk '{print $2}'"
        ).strip()
        
        print(f"Balanced profile time: {balanced_time}s")
        print(f"Performance profile time: {performance_time}s")
  '';
}
