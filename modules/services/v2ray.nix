{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.v2ray;
  
  # V2Ray configuration as a separate value
  v2rayConfig = {
    inbounds = [
      {
        port = 1080;
        protocol = "socks";
        settings = {
          auth = "noauth";
          udp = true;
        };
        tag = "socks-in";
      }
      {
        port = 8118;
        protocol = "http";
        settings = { };
        tag = "http-in";
      }
    ];

    outbounds = [
      {
        protocol = "vless";
        settings = {
          vnext = [
            {
              address = "example.com";  # Will be replaced by secrets
              port = 443;
              users = [
                {
                  id = "00000000-0000-0000-0000-000000000000";  # Will be replaced by secrets
                  encryption = "none";
                  flow = "";
                }
              ];
            }
          ];
        };
        streamSettings = {
          network = "tcp";
          security = "reality";
          realitySettings = {
            serverName = "google.com";
            fingerprint = "firefox";
            publicKey = "example_public_key";  # Will be replaced by secrets
            shortId = "";
            spiderX = "/";
          };
        };
        tag = "proxy";
      }
      {
        protocol = "freedom";
        settings = { };
        tag = "direct";
      }
      {
        protocol = "blackhole";
        settings = { };
        tag = "block";
      }
    ];

    routing = {
      domainStrategy = "IPIfNonMatch";
      rules = [
        {
          type = "field";
          domain = [
            "geosite:category-ads"
          ];
          outboundTag = "block";
        }
        {
          type = "field";
          domain = [
            "geosite:cn"
            "geosite:private"
          ];
          outboundTag = "direct";
        }
        {
          type = "field";
          ip = [
            "geoip:cn"
            "geoip:private"
          ];
          outboundTag = "direct";
        }
        {
          type = "field";
          network = "tcp,udp";
          outboundTag = "proxy";
        }
      ];
    };

    dns = {
      servers = [
        "8.8.8.8"
        "223.5.5.5"
        "localhost"
      ];
    };
  };
in
{
  options.services.v2ray = {
    enable = mkEnableOption "V2Ray proxy service";
    
    useSecrets = mkOption {
      type = types.bool;
      default = false;
      description = "Use SOPS secrets for V2Ray configuration";
    };
  };

  config = mkIf cfg.enable {
    # V2Ray service configuration
    services.v2ray = {
      enable = true;
      config = v2rayConfig;
    };

    # Open firewall ports
    networking.firewall = {
      allowedTCPPorts = [ 1080 8118 ];
    };

    # Add v2ray package
    environment.systemPackages = with pkgs; [
      v2ray
    ];
  };
}