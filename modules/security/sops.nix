{ config, pkgs, inputs, ... }:

{
  # SOPS-nix configuration for secrets management

  # Import sops-nix module (done in flake.nix)

  sops = {
    # Default sops file location
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Age key file location
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    # Define secrets
    secrets = {
      # Example secrets (uncomment and configure as needed)

      # "wifi_password" = {
      #   sopsFile = ../../secrets/wifi.yaml;
      # };

      # "github_token" = {
      #   sopsFile = ../../secrets/github.yaml;
      #   owner = "semyenov";
      # };

      # "docker_hub_token" = {
      #   sopsFile = ../../secrets/docker.yaml;
      #   owner = "semyenov";
      # };

      # "ssh_private_key" = {
      #   sopsFile = ../../secrets/ssh.yaml;
      #   path = "/home/semyenov/.ssh/id_ed25519";
      #   owner = "semyenov";
      #   mode = "0600";
      # };
    };

    # Templates for files that need secrets embedded
    templates = {
      # Example template for a config file with secrets
      # "app_config" = {
      #   content = ''
      #     api_key = "${config.sops.placeholder."api_key"}"
      #     database_url = "${config.sops.placeholder."database_url"}"
      #   '';
      #   owner = "semyenov";
      # };
    };
  };

  # Environment variables for systemd services
  # systemd.services.example-service = {
  #   serviceConfig = {
  #     EnvironmentFile = config.sops.secrets."service_env".path;
  #   };
  # };

  # Tools for managing secrets
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
  ];
}
