{ config, pkgs, ... }:

{
  # Disable PulseAudio
  services.pulseaudio.enable = false;

  # Enable realtime kit for better audio performance
  security.rtkit.enable = true;

  # PipeWire configuration
  services.pipewire = {
    enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    jack.enable = true;

    # Use extraConfig for PipeWire configuration
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 8192;
      };
    };

    extraConfig.pipewire-pulse."92-low-latency" = {
      "context.properties" = {
        "log.level" = 2;
      };

      "pulse.properties" = {
        "pulse.min.req" = "32/48000";
        "pulse.default.req" = "256/48000";
        "pulse.max.req" = "8192/48000";
        "pulse.min.quantum" = "32/48000";
        "pulse.max.quantum" = "8192/48000";
      };

      "stream.properties" = {
        "node.latency" = "256/48000";
        "resample.quality" = 10;
      };
    };
  };

  # Audio tools
  environment.systemPackages = with pkgs; [
    pavucontrol # PulseAudio volume control
    helvum # PipeWire patchbay
    easyeffects # Audio effects for PipeWire
    playerctl # Media player control
    pamixer # PulseAudio mixer
    pulseaudio # For pactl commands
  ];
}
