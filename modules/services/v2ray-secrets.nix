{ config, pkgs, lib, ... }:

# This module handles V2Ray with SOPS secrets
# Enable it only when you have configured secrets

with lib;

let
  cfg = config.services.v2rayWithSecrets;
in
{
  options.services.v2rayWithSecrets = {
    enable = mkEnableOption "V2Ray with SOPS secrets";
  };

  config = mkIf cfg.enable {
    # Define SOPS secrets
    sops.secrets = {
      "v2ray/server_address" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/server_port" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/user_id" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/public_key" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/short_id" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
    };

    # Override V2Ray configuration with secrets
    services.v2ray = {
      enable = true;
      config = {
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

        routing = {
          domainStrategy = "IPIfNonMatch";
          rules = [
            {
              type = "field";
              domain = [ "geosite:category-ads" ];
              outboundTag = "block";
            }
            {
              type = "field";
              domain = [ "geosite:cn" "geosite:private" ];
              outboundTag = "direct";
            }
            {
              type = "field";
              ip = [ "geoip:cn" "geoip:private" ];
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
          servers = [ "8.8.8.8" "223.5.5.5" "localhost" ];
        };
      };
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