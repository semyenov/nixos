{ config, pkgs, lib, ... }:

let
  # V2Ray configuration can be enabled/disabled
  cfg = config.services.v2ray;
in

{
  # V2Ray service configuration with VLESS
  # NOTE: Set services.v2ray.enable = true in your host config to enable
  services.v2ray = {
    enable = lib.mkDefault false; # Disabled by default

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
                # Use SOPS secrets if available, otherwise use example values
                address =
                  if config.sops.secrets ? "v2ray/server_address"
                  then lib.strings.fileContents config.sops.secrets."v2ray/server_address".path
                  else "2ppn.viapip.com";
                port =
                  if config.sops.secrets ? "v2ray/server_port"
                  then lib.toInt (lib.strings.fileContents config.sops.secrets."v2ray/server_port".path)
                  else 8080;
                users = [
                  {
                    id =
                      if config.sops.secrets ? "v2ray/user_id"
                      then lib.strings.fileContents config.sops.secrets."v2ray/user_id".path
                      else "16bb4a8e-5ff5-429f-8df4-d0b8169caf2b";
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
              publicKey =
                if config.sops.secrets ? "v2ray/public_key"
                then lib.strings.fileContents config.sops.secrets."v2ray/public_key".path
                else "S9JCk4TdwTxWkzzLd4gtBQjzdKzqK8w_1FUmvA2gPAs";
              shortId =
                if config.sops.secrets ? "v2ray/short_id"
                then lib.strings.fileContents config.sops.secrets."v2ray/short_id".path
                else "98502117";
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
}
