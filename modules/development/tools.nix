{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Version control
    git
    lazygit
    gh
    glab
    delta  # Better git diff
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
    sd  # Better sed
    jq
    yq
    xh  # Better curl
    httpie
    
    # File management
    ranger
    nnn
    broot
    xplr
    
    # System monitoring
    htop
    btop
    iotop
    nethogs
    bandwhich
    procs
    bottom
    
    # Development tools
    direnv
    nix-direnv
    watchman
    entr
    just
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
    sqlite
    pgcli
    mycli
    litecli
    usql
    
    # Cloud tools
    awscli2
    google-cloud-sdk
    azure-cli
    terraform
    kubectl
    k9s
    helm
    
    # Documentation
    mdbook
    pandoc
    typst
    
    # Debugging
    gdb
    lldb
    strace
    ltrace
    hyperfine  # Benchmarking
    
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