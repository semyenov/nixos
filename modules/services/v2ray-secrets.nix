{ config, pkgs, lib, ... }:

# This module configures V2Ray with SOPS secrets
# It uses the official NixOS v2ray module with secrets integration

with lib;

let
  cfg = config.services.v2rayWithSecrets;
  
  # Generate V2Ray config file at build time
  v2rayConfigFile = pkgs.writeText "v2ray-config.json" (builtins.toJSON {
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
              # These will be replaced at runtime by a wrapper script
              address = "SOPS_SERVER_ADDRESS";
              port = 443;
              users = [
                {
                  id = "SOPS_USER_ID";
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
            publicKey = "SOPS_PUBLIC_KEY";
            shortId = "SOPS_SHORT_ID";
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
  });
  
  # Wrapper script that replaces placeholders with actual secrets
  v2rayWrapper = pkgs.writeShellScript "v2ray-wrapper" ''
    # Read secrets
    SERVER_ADDRESS=$(cat ${config.sops.secrets."v2ray/server_address".path})
    SERVER_PORT=$(cat ${config.sops.secrets."v2ray/server_port".path})
    USER_ID=$(cat ${config.sops.secrets."v2ray/user_id".path})
    PUBLIC_KEY=$(cat ${config.sops.secrets."v2ray/public_key".path})
    SHORT_ID=$(cat ${config.sops.secrets."v2ray/short_id".path})
    
    # Create temporary config with secrets substituted
    CONFIG_FILE=$(mktemp)
    cat ${v2rayConfigFile} | \
      sed "s/SOPS_SERVER_ADDRESS/$SERVER_ADDRESS/g" | \
      sed "s/443/$SERVER_PORT/g" | \
      sed "s/SOPS_USER_ID/$USER_ID/g" | \
      sed "s/SOPS_PUBLIC_KEY/$PUBLIC_KEY/g" | \
      sed "s/SOPS_SHORT_ID/$SHORT_ID/g" > "$CONFIG_FILE"
    
    # Run v2ray with the config
    exec ${pkgs.v2ray}/bin/v2ray run -config "$CONFIG_FILE"
  '';
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

    # Custom systemd service for V2Ray with secrets
    systemd.services.v2ray-with-secrets = {
      description = "V2Ray Service with SOPS Secrets";
      after = [ "network.target" "sops-nix.service" ];
      wants = [ "network.target" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStart = v2rayWrapper;
        Restart = "on-failure";
        RestartSec = 10;
        
        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/run" "/tmp" ];
      };
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