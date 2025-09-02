# Development Shells
# Modular shell environments with shared base and specialized extensions

{ pkgs ? import <nixpkgs> { } }:

let
  inherit (pkgs) lib;
  # Base shell with common development tools
  baseShell = pkgs.mkShell {
    name = "base-dev";
    buildInputs = with pkgs; [
      # Core development tools
      git
      gh
      jq
      yq
      ripgrep
      fd
      bat
      eza
      tree
      htop
      btop
      ncdu
    ];

    shellHook = ''
      # Set up useful aliases
      alias ll="eza -la --icons"
      alias la="eza -a --icons"
      alias lt="eza --tree --icons"
    '';
  };

  # Create specialized shell by extending base shell
  mkSpecializedShell = name: description: extraPackages: extraHook:
    baseShell.overrideAttrs (oldAttrs: {
      name = "${name}-dev";
      buildInputs = oldAttrs.buildInputs ++ extraPackages;
      shellHook = oldAttrs.shellHook + "\n" + ''
        echo "🚀 ${description}"
        echo "📝 Project: $(pwd)"
        echo "🌿 Git branch: $(git branch --show-current 2>/dev/null || echo 'not in git repo')"
        echo ""
      '' + extraHook;
    });
in
{
  # NixOS configuration development shell
  nixos = mkSpecializedShell
    "NixOS Configuration"
    "NixOS Configuration Development Environment"
    (with pkgs; [
      # Nix tools
      nixpkgs-fmt
      nil
      statix
      deadnix
      nix-tree
      nix-diff
      nix-prefetch
      nix-output-monitor
      nvd

      # Task automation
      go-task

      # Secrets management
      sops
      age
      ssh-to-age
      git-crypt

      # Documentation
      mdbook
      pandoc
    ])
    ''
      echo "📦 Available tools:"
      echo "  • Nix: nixpkgs-fmt, nil, statix, deadnix, nix-tree"
      echo "  • Task: task (run 'task --list-all' for commands)"
      echo "  • Secrets: sops, age"
      echo "  • Git: git, gh"
      echo ""
      echo "🔧 Quick commands:"
      echo "  task test       - Run all tests"
      echo "  task rebuild    - Rebuild system"
      echo "  task format     - Format nix files"
      echo "  task clean      - Clean old generations"
    '';

  # Web development (TypeScript/JavaScript)
  web = mkSpecializedShell
    "Web Development"
    "TypeScript/JavaScript Development Environment"
    (with pkgs; [
      nodejs_22
      nodePackages.pnpm
      nodePackages.yarn
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodePackages.eslint
      nodePackages.prettier
      bun
      deno
    ])
    ''
      echo "Node: $(node --version)"
      echo "TypeScript: $(tsc --version)"
      echo "Available runtimes: node, bun, deno"
      echo "Package managers: npm, yarn, pnpm"
    '';

  # Systems programming (Rust/Go/C++)
  systems = mkSpecializedShell
    "Systems Programming"
    "Rust/Go/C++ Development Environment"
    (with pkgs; [
      # Rust
      rustc
      cargo
      rust-analyzer
      rustfmt
      clippy

      # Go
      go
      gopls
      golangci-lint

      # C/C++
      gcc
      clang
      cmake
      ninja
      gdb
      pkg-config
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      # Linux-only tools
      valgrind
    ])
    ''
      echo "🦀 Rust: $(rustc --version)"
      echo "🐹 Go: $(go version)"
      echo "🔧 C/C++: $(gcc --version | head -1)"
      echo ""
      echo "Available tools:"
      echo "  • Rust: cargo, rust-analyzer, clippy"
      echo "  • Go: go, gopls, golangci-lint"
      echo "  • C/C++: gcc, clang, cmake, gdb"
    '';

  # Data & DevOps
  ops = mkSpecializedShell
    "Data & DevOps"
    "Data Science & DevOps Environment"
    (with pkgs; [
      # Python data science
      python311
      python311Packages.pip
      python311Packages.virtualenv
      python311Packages.jupyter
      python311Packages.pandas
      python311Packages.numpy
      python311Packages.matplotlib

      # DevOps tools  
      docker
      docker-compose
      kubectl
      helm
      terraform
      ansible

      # Database tools
      postgresql
      sqlite
      redis

      # Monitoring
      prometheus
      grafana
    ])
    ''
      echo "🐍 Python: $(python --version)"
      echo "🐳 Docker: $(docker --version)"
      echo "☸️  Kubernetes: $(kubectl version --client --short 2>/dev/null || echo 'kubectl available')"
      echo ""
      echo "Available tools:"
      echo "  • Python: pip, virtualenv, jupyter, pandas, numpy"
      echo "  • DevOps: docker, kubectl, terraform, ansible"
      echo "  • Databases: postgresql, sqlite, redis"
      echo "  • Monitoring: prometheus, grafana"
    '';

  # Security & mobile (consolidated)
  mobile = mkSpecializedShell
    "Mobile & Security"
    "Mobile Development & Security Testing Environment"
    (with pkgs; [
      # Mobile development
      flutter
      android-tools

      # Security tools
      nmap
      wireshark
      tcpdump
      openssl
      gnupg
      pass

      # Network analysis
      netcat
      socat
      curl
      wget
    ] ++ lib.optionals (pkgs.stdenv.system == "x86_64-linux") [
      # Platform-specific packages
      android-studio
    ])
    ''
      echo "📱 Flutter: $(flutter --version | head -1)"
      echo "🔒 Security tools: nmap, wireshark, openssl, gnupg"
      echo "📡 Network: netcat, socat, curl, wget"
      echo ""
      echo "Available environments:"
      echo "  • Mobile: flutter, android-tools"
      echo "  • Security: nmap, wireshark, tcpdump"
      echo "  • Crypto: openssl, gnupg, pass"
    '';
}
