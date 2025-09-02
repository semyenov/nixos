{ config, pkgs, ... }:

{
  imports = [
    # Hardware-specific configuration (auto-generated)
    ./hardware-configuration.nix
  ];

  # ========================
  # BOOT & KERNEL
  # ========================
  
  boot = {
    # EFI bootloader configuration
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    
    # Use latest kernel for better hardware support (especially NVIDIA)
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # ========================
  # HARDWARE
  # ========================
  
  # NVIDIA RTX 4060 Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  
  hardware = {
    # Graphics configuration
    graphics = {
      enable = true;
      enable32Bit = true;  # Required for Steam and 32-bit games
    };
    
    # NVIDIA-specific settings
    nvidia = {
      # Use proprietary drivers (better performance than open source)
      open = false;
      
      # Enable kernel modesetting (required for Wayland)
      modesetting.enable = true;
      
      # Power management (useful for laptops, optional for desktops)
      powerManagement.enable = true;
      
      # NVIDIA Settings GUI application
      nvidiaSettings = true;
      
      # Driver package selection
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  # ========================
  # NETWORKING
  # ========================
  
  networking = {
    hostName = "nixos";
    
    # NetworkManager for easy network configuration
    networkmanager.enable = true;
  };

  # ========================
  # LOCALIZATION
  # ========================
  
  # Timezone
  time.timeZone = "Europe/Moscow";

  # Locale settings
  i18n = {
    defaultLocale = "en_US.UTF-8";
    
    # Russian formatting while keeping English UI
    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "ru_RU.UTF-8";
    };
  };

  # ========================
  # DESKTOP ENVIRONMENT
  # ========================
  
  services.xserver = {
    enable = true;
    
    # GNOME Desktop
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    
    # Keyboard layout
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # ========================
  # AUDIO
  # ========================
  
  # Disable PulseAudio (we're using PipeWire)
  services.pulseaudio.enable = false;
  
  # Enable realtime kit for better audio performance
  security.rtkit.enable = true;
  
  # PipeWire configuration (modern audio system)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;  # 32-bit support for games
    pulse.enable = true;        # PulseAudio compatibility
  };

  # ========================
  # SERVICES
  # ========================
  
  services = {
    # Printing support
    printing.enable = true;
    
    # SSH server
    openssh.enable = true;
  };

  # ========================
  # VIRTUALIZATION
  # ========================
  
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    
    # Overlay2 is the recommended storage driver
    storageDriver = "overlay2";
  };

  # ========================
  # USER CONFIGURATION
  # ========================
  
  users.users.semyenov = {
    isNormalUser = true;
    description = "Alexander Semyenov";
    
    # User groups
    extraGroups = [ 
      "networkmanager"  # Network management
      "wheel"          # sudo access
      "docker"         # Docker without sudo
    ];
    
    # User-specific packages
    packages = with pkgs; [
      # Communication
      thunderbird
      telegram-desktop
      
      # Browsers
      brave
      
      # Security
      gopass
      
      # Gaming
      lutris
      
      # Development
      code-cursor
      claude-code
      
      # Terminal
      ghostty
    ];
  };

  # ========================
  # SYSTEM PACKAGES
  # ========================
  
  # Allow unfree packages (required for NVIDIA, some apps)
  nixpkgs.config.allowUnfree = true;
  
  # Firefox as system-wide browser
  programs.firefox.enable = true;
  
  environment.systemPackages = with pkgs; [
    # Text editors
    neovim
    
    # Basic utilities
    wget
    git
    
    # NVIDIA tools
    nvidia-vaapi-driver  # Hardware video acceleration
    libva               # Video acceleration API
    
    # Networking
    nekoray
    
    # JavaScript/TypeScript development
    nodejs_22
    nodePackages.npm
    nodePackages.pnpm
    nodePackages.yarn
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.eslint
    nodePackages.prettier
    
    # Alternative JS runtimes
    bun
    deno
    
    # Container tools
    docker-compose
    lazydocker
    
    # Git tools
    lazygit
    gh  # GitHub CLI
    
    # CLI utilities
    httpie      # Better curl
    jq          # JSON processor
    ripgrep     # Better grep
    fd          # Better find
    bat         # Better cat
    eza         # Better ls
    zoxide      # Better cd
    fzf         # Fuzzy finder
    tmux        # Terminal multiplexer
    direnv      # Environment management
  ];

  # ========================
  # PROGRAMS CONFIGURATION
  # ========================
  
  programs = {
    # Network diagnostics
    mtr.enable = true;
    
    # GPG agent for encryption
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # ========================
  # NIX CONFIGURATION
  # ========================
  
  nix.settings.experimental-features = [
    "nix-command"  # New nix CLI
    "flakes"       # Flakes support
  ];

  # ========================
  # SYSTEM VERSION
  # ========================
  
  # DO NOT CHANGE unless following migration guide
  # This defines the NixOS release with which your system is compatible
  system.stateVersion = "25.05";
}