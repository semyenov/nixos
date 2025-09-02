{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.v2ray;
in
{
  # V2Ray service configuration with VLESS and SOPS integration
  # NOTE: Set services.v2ray.enable = true in your host config to enable
  
  options.services.v2ray = {
    enable = mkEnableOption "V2Ray proxy service";
  };

  config = mkIf cfg.enable {
    # Define SOPS secrets with proper service integration
    sops.secrets = {
      "v2ray/server_address" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = config.users.users.v2ray.name or "root";
        restartUnits = [ "v2ray.service" ];
      };
      "v2ray/server_port" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = config.users.users.v2ray.name or "root";
        restartUnits = [ "v2ray.service" ];
      };
      "v2ray/user_id" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = config.users.users.v2ray.name or "root";
        restartUnits = [ "v2ray.service" ];
      };
      "v2ray/public_key" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = config.users.users.v2ray.name or "root";
        restartUnits = [ "v2ray.service" ];
      };
      "v2ray/short_id" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = config.users.users.v2ray.name or "root";
        restartUnits = [ "v2ray.service" ];
      };
    };

    # V2Ray service configuration
    services.v2ray = {
      enable = true;
      
      config = {
        # Inbound configuration for local SOCKS/HTTP proxy
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

        # Outbound configuration for VLESS
        outbounds = [
          {
            protocol = "vless";
            settings = {
              vnext = [
                {
                  # SOPS secrets are required for V2Ray to work
                  address = lib.strings.fileContents config.sops.secrets."v2ray/server_address".path;
                  port = lib.toInt (lib.strings.fileContents config.sops.secrets."v2ray/server_port".path);
                  users = [
                    {
                      id = lib.strings.fileContents config.sops.secrets."v2ray/user_id".path;
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
                publicKey = lib.strings.fileContents config.sops.secrets."v2ray/public_key".path;
                shortId = lib.strings.fileContents config.sops.secrets."v2ray/short_id".path;
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

        # Routing rules
        routing = {
          domainStrategy = "IPIfNonMatch";
          rules = [
            # Block ads and tracking
            {
              type = "field";
              domain = [
                "geosite:category-ads"
                "geosite:category-ads-all"
              ];
              outboundTag = "block";
            }
            # Direct connection for local and China sites
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
            # Everything else through proxy
            {
              type = "field";
              network = "tcp,udp";
              outboundTag = "proxy";
            }
          ];
        };

        # DNS configuration
        dns = {
          servers = [
            {
              address = "8.8.8.8";
              port = 53;
              domains = [
                "geosite:geolocation-!cn"
              ];
            }
            {
              address = "223.5.5.5";
              port = 53;
              domains = [
                "geosite:cn"
              ];
            }
            "localhost"
          ];
        };

        # Policy configuration
        policy = {
          levels = {
            "0" = {
              handshake = 4;
              connIdle = 300;
              uplinkOnly = 2;
              downlinkOnly = 5;
              statsUserUplink = false;
              statsUserDownlink = false;
              bufferSize = 4;
            };
          };
          system = {
            statsInboundUplink = false;
            statsInboundDownlink = false;
            statsOutboundUplink = false;
            statsOutboundDownlink = false;
          };
        };
      };
    };

    # Ensure V2Ray service waits for secrets to be available
    systemd.services.v2ray = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      
      # Add assertions to ensure secrets exist
      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/test -f ${config.sops.secrets."v2ray/user_id".path}";
      };
    };

    # Open firewall ports for local proxy
    networking.firewall = {
      allowedTCPPorts = [ 1080 8118 ];
    };

    # System proxy environment variables (optional)
    # Uncomment to set system-wide proxy
    # environment.sessionVariables = {
    #   http_proxy = "http://127.0.0.1:8118";
    #   https_proxy = "http://127.0.0.1:8118";
    #   socks_proxy = "socks5://127.0.0.1:1080";
    #   no_proxy = "localhost,127.0.0.0/8,::1";
    # };

    # Add v2ray package
    environment.systemPackages = with pkgs; [
      v2ray
    ];
  };
}