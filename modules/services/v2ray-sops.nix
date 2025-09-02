{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.v2ray;
in
{
  # SOPS secrets configuration for V2Ray service
  # This module provides proper systemd integration for secrets
  
  config = mkIf (cfg.enable or false) {
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

    # Ensure V2Ray service waits for secrets to be available
    systemd.services.v2ray = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
      
      # Add assertions to ensure secrets exist
      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/test -f ${config.sops.secrets."v2ray/user_id".path}";
      };
    };
  };
}
