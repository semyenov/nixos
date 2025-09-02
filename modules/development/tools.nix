{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Version control
    git
    lazygit
    gh
    glab
    delta # Better git diff
    git-lfs
    git-crypt

    # Text editors
    neovim
    helix

    # Terminal tools
    tmux
    zellij
    wezterm
    alacritty
    ghostty

    # Shell enhancements
    starship
    zoxide
    fzf
    eza
    bat
    fd
    ripgrep
    sd # Better sed
    jq
    yq
    xh # Better curl
    httpie

    # File management (all lightweight TUI tools)
    ranger # Vim-like file manager
    nnn # Blazing fast file manager
    broot # Tree-based file manager
    xplr # Hackable file manager

    # System monitoring (all lightweight, keep for different use cases)
    htop # Classic process viewer
    btop # Modern resource monitor
    iotop # IO monitoring
    nethogs # Network per-process
    bandwhich # Network utilization
    procs # Modern ps
    bottom # Another resource monitor

    # Development tools
    direnv
    nix-direnv
    watchman
    entr
    just
    go-task # Modern task runner with YAML config
    gnumake
    cmake
    meson

    # Language tools
    python312
    poetry
    rustup
    go
    zig

    # Database tools
    sqlite # Lightweight
    pgcli # Lightweight CLI
    mycli # Lightweight CLI
    litecli # Lightweight CLI
    usql # Lightweight universal CLI

    # Cloud tools
    # awscli2          # ~500 MB - heavy CLI
    # google-cloud-sdk # ~500 MB - heavy CLI
    # azure-cli        # ~500 MB - heavy CLI
    terraform # Keep lightweight IaC tool
    kubectl # Keep lightweight k8s tool
    k9s # Keep lightweight k8s TUI
    helm # Keep lightweight package manager

    # Documentation
    mdbook
    pandoc
    typst

    # Debugging
    gdb
    lldb
    strace
    ltrace
    hyperfine # Benchmarking

    # Archive tools
    unzip
    unrar
    p7zip

    # Network tools
    wget
    curl
    aria2
    rsync
    rclone
  ];

  # Programs configuration
  programs = {
    # Enable mtr for network diagnostics
    mtr.enable = true;

    # GPG agent
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # Enable Git
    git = {
      enable = true;
      lfs.enable = true;
    };

    # Enable direnv
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Enable starship prompt
    starship = {
      enable = true;
      settings = {
        format = "$all$character";
        add_newline = true;
      };
    };
  };
}
