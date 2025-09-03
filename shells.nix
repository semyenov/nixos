# Development Shells
# Simplified shell environments for different development workflows

{ pkgs ? import <nixpkgs> { } }:

let
  inherit (pkgs) lib;

  # Common development tools across all shells
  commonTools = with pkgs; [
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

  # Common shell hook with aliases
  commonHook = ''
    alias ll="eza -la --icons"
    alias la="eza -a --icons"  
    alias lt="eza --tree --icons"
    echo "📝 Project: $(pwd)"
    echo "🌿 Git: $(git branch --show-current 2>/dev/null || echo 'not in git repo')"
  '';
in
{
  # NixOS configuration development
  nixos = pkgs.mkShell {
    name = "nixos-dev";
    buildInputs = commonTools ++ (with pkgs; [
      nixpkgs-fmt
      nil
      statix
      deadnix
      nix-tree
      nix-output-monitor
      go-task
      sops
      age
      ssh-to-age
      git-crypt
      mdbook
      pandoc
    ]);

    shellHook = commonHook + ''
      echo "🚀 NixOS Configuration Development"
      echo "Tools: nixpkgs-fmt, nil, statix, sops, task"
      echo "Commands: task test | task rebuild | task format"
    '';
  };

  # Web development (TypeScript/JavaScript)
  web = pkgs.mkShell {
    name = "web-dev";
    buildInputs = commonTools ++ (with pkgs; [
      nodejs_22
      nodePackages.pnpm
      nodePackages.yarn
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodePackages.eslint
      nodePackages.prettier
      bun
      deno
    ]);

    shellHook = commonHook + ''
      echo "🌐 Web Development Environment"
      echo "Node: $(node --version) | TypeScript: $(tsc --version)"
      echo "Runtimes: node, bun, deno | Managers: npm, yarn, pnpm"
    '';
  };

  # Systems programming (Rust/Go/C++)
  systems = pkgs.mkShell {
    name = "systems-dev";
    buildInputs = commonTools ++ (with pkgs; [
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
    ] ++ lib.optionals pkgs.stdenv.isLinux [ valgrind ]);

    shellHook = commonHook + ''
      echo "⚙️  Systems Programming Environment"
      echo "🦀 Rust: $(rustc --version | cut -d' ' -f2)"
      echo "🐹 Go: $(go version | cut -d' ' -f3)"
      echo "🔧 C/C++: $(gcc --version | head -1 | cut -d' ' -f3)"
    '';
  };

  # Data science & DevOps
  ops = pkgs.mkShell {
    name = "ops-dev";
    buildInputs = commonTools ++ (with pkgs; [
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
      terraform
      ansible

      # Databases  
      postgresql
      sqlite
      redis

      # Monitoring
      prometheus
      grafana
    ] ++ lib.optionals pkgs.stdenv.isLinux [ helm ]);

    shellHook = commonHook + ''
      echo "🔧 Data Science & DevOps Environment" 
      echo "🐍 Python: $(python --version)"
      echo "🐳 Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
      echo "Tools: kubectl, terraform, ansible, jupyter, pandas"
    '';
  };

  # Mobile development & security testing
  mobile = pkgs.mkShell {
    name = "mobile-dev";
    buildInputs = commonTools ++ (with pkgs; [
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
    ] ++ lib.optionals (pkgs.stdenv.system == "x86_64-linux") [ android-studio ]);

    shellHook = commonHook + ''
      echo "📱 Mobile Development & Security Environment"
      echo "🎯 Flutter: $(flutter --version | head -1 | cut -d' ' -f2)"
      echo "🔒 Security: nmap, wireshark, openssl, gnupg"
      echo "📡 Network: netcat, socat, curl, wget"
    '';
  };
}
