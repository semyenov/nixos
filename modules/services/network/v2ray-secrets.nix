{ config, pkgs, lib, ... }:

# This module provides a custom V2Ray service with SOPS secrets
# It does not use the official NixOS v2ray module to avoid conflicts

with lib;

let
  cfg = config.services.v2rayWithSecrets;
  centralConfig = import ../../../lib/config.nix;
  utils = import ../../../lib/module-utils.nix { inherit lib; };
  ports = centralConfig.network.ports.v2ray;

  # Static V2Ray configuration with placeholders
  v2rayConfigTemplate = {
    inbounds = [
      {
        port = ports.socks;
        protocol = "socks";
        settings = {
          auth = "noauth";
          udp = true;
        };
        tag = "socks-in";
      }
      {
        port = ports.http;
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
              address = "SOPS_SERVER_ADDRESS";
              port = "SOPS_SERVER_PORT";
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
      servers = centralConfig.network.dns.primary ++ centralConfig.network.dns.chinese ++ [ "localhost" ];
    };
  };
in
{
  options.services.v2rayWithSecrets = {
    enable = utils.mkServiceEnableOption "v2rayWithSecrets" "V2Ray proxy service with SOPS-encrypted configuration";
  };

  config = mkIf cfg.enable {
    # Assertions
    assertions = [
      (utils.mkAssertion
        (config.sops.secrets ? "v2ray/server_address")
        "V2Ray requires SOPS secrets to be configured. Please set up secrets/v2ray.yaml")
    ];

    # Define SOPS secrets for V2Ray
    sops.secrets = {
      "v2ray/server_address" = {
        sopsFile = ../../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/server_port" = {
        sopsFile = ../../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/user_id" = {
        sopsFile = ../../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/public_key" = {
        sopsFile = ../../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
      "v2ray/short_id" = {
        sopsFile = ../../../secrets/v2ray.yaml;
        mode = "0400";
        owner = "root";
      };
    };

    # Custom systemd service for V2Ray (not using services.v2ray at all)
    systemd.services.v2ray-custom = {
      description = "Custom V2Ray Service with SOPS Secrets";
      after = [ "network.target" "sops-nix.service" ];
      wants = [ "network.target" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStartPre = pkgs.writeShellScript "v2ray-pre-start" ''
          # Ensure secrets are available
          test -f ${config.sops.secrets."v2ray/server_address".path}
          test -f ${config.sops.secrets."v2ray/server_port".path}
          test -f ${config.sops.secrets."v2ray/user_id".path}
          test -f ${config.sops.secrets."v2ray/public_key".path}
          test -f ${config.sops.secrets."v2ray/short_id".path}
        '';
        ExecStart = pkgs.writeShellScript "v2ray-start" ''
          # Read secrets
          SERVER_ADDRESS=$(cat ${config.sops.secrets."v2ray/server_address".path})
          SERVER_PORT=$(cat ${config.sops.secrets."v2ray/server_port".path})
          USER_ID=$(cat ${config.sops.secrets."v2ray/user_id".path})
          PUBLIC_KEY=$(cat ${config.sops.secrets."v2ray/public_key".path})
          SHORT_ID=$(cat ${config.sops.secrets."v2ray/short_id".path})
          
          # Create config with secrets
          CONFIG_FILE=$(mktemp --suffix=.json)
          trap "rm -f $CONFIG_FILE" EXIT
          
          echo '${builtins.toJSON v2rayConfigTemplate}' | \
            ${pkgs.jq}/bin/jq \
              --arg addr "$SERVER_ADDRESS" \
              --arg port "$SERVER_PORT" \
              --arg uid "$USER_ID" \
              --arg pubkey "$PUBLIC_KEY" \
              --arg sid "$SHORT_ID" \
              '.outbounds[0].settings.vnext[0].address = $addr |
               .outbounds[0].settings.vnext[0].port = ($port | tonumber) |
               .outbounds[0].settings.vnext[0].users[0].id = $uid |
               .outbounds[0].streamSettings.realitySettings.publicKey = $pubkey |
               .outbounds[0].streamSettings.realitySettings.shortId = $sid' \
              > "$CONFIG_FILE"
          
          # Run v2ray
          exec ${pkgs.v2ray}/bin/v2ray run -config "$CONFIG_FILE"
        '';
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
      jq # For JSON processing
    ];
  };
}
