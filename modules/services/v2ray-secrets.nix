{ config, pkgs, lib, ... }:

# This module configures V2Ray with SOPS secrets
# It uses the official NixOS v2ray module with secrets integration

with lib;

let
  cfg = config.services.v2rayWithSecrets;
in
{
  options.services.v2rayWithSecrets = {
    enable = mkEnableOption "V2Ray proxy with SOPS secrets";
  };

  config = mkIf cfg.enable {
    # Define SOPS secrets for V2Ray
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

    # Enable the official V2Ray service with custom configuration
    services.v2ray = {
      enable = true;
      configFile = let
        # Read secrets at runtime
        serverAddress = lib.strings.fileContents config.sops.secrets."v2ray/server_address".path;
        serverPort = lib.strings.fileContents config.sops.secrets."v2ray/server_port".path;
        userId = lib.strings.fileContents config.sops.secrets."v2ray/user_id".path;
        publicKey = lib.strings.fileContents config.sops.secrets."v2ray/public_key".path;
        shortId = lib.strings.fileContents config.sops.secrets."v2ray/short_id".path;
        
        # V2Ray configuration
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
                    address = serverAddress;
                    port = lib.toInt serverPort;
                    users = [
                      {
                        id = userId;
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
                  publicKey = publicKey;
                  shortId = shortId;
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
      in pkgs.writeText "v2ray-config.json" (builtins.toJSON v2rayConfig);
    };

    # Ensure V2Ray service waits for secrets
    systemd.services.v2ray = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
    };

    # Open firewall ports for local proxy
    networking.firewall = {
      allowedTCPPorts = [ 1080 8118 ];
    };

    # Add v2ray package
    environment.systemPackages = with pkgs; [
      v2ray
    ];
  };
}