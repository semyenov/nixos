{ config, lib, ... }:

{
  # SOPS secrets configuration for V2Ray
  # Only configure if V2Ray is enabled
  config = lib.mkIf (config.services.v2ray.enable or false) {
    sops.secrets = {
      "v2ray/server_address" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
      };
      "v2ray/server_port" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
      };
      "v2ray/user_id" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
      };
      "v2ray/public_key" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
      };
      "v2ray/short_id" = {
        sopsFile = ../../secrets/v2ray.yaml;
        mode = "0400";
      };
    };
  };
}
