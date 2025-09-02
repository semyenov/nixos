{ pkgs ? import <nixpkgs> { } }:

{
  # NixOS configuration development shell
  nixos = pkgs.mkShell {
    name = "nixos-config-dev";
    buildInputs = with pkgs; [
      # Nix tools
      nixpkgs-fmt # Format nix files
      nil # Nix LSP
      statix # Lint nix files
      deadnix # Find dead nix code
      nix-tree # Visualize dependencies
      nix-diff # Diff nix derivations
      nix-prefetch # Prefetch sources
      nix-output-monitor # Better nix build output
      nvd # Nix version diff

      # Task automation
      go-task # Task runner

      # Secrets management
      sops # Encrypt/decrypt secrets
      age # Encryption tool
      ssh-to-age # Convert SSH keys to age

      # Git tools
      git # Version control
      gh # GitHub CLI
      git-crypt # Transparent file encryption in git

      # System tools
      htop # Process viewer
      btop # Better process viewer
      ncdu # Disk usage analyzer
      tree # Directory tree viewer
      jq # JSON processor
      yq # YAML processor
      ripgrep # Fast grep
      fd # Fast find
      bat # Better cat
      eza # Better ls

      # Documentation
      mdbook # Create books from markdown
      pandoc # Document converter
    ];

    shellHook = ''
      echo "🚀 NixOS Configuration Development Environment"
      echo ""
      echo "📦 Available tools:"
      echo "  • Nix: nixpkgs-fmt, nil, statix, deadnix, nix-tree"
      echo "  • Task: task (run 'task --list-all' for commands)"
      echo "  • Secrets: sops, age"
      echo "  • Git: git, gh"
      echo "  • Utils: jq, yq, ripgrep (rg), fd, bat, eza"
      echo ""
      echo "🔧 Quick commands:"
      echo "  task test       - Run all tests"
      echo "  task rebuild    - Rebuild system"
      echo "  task format     - Format nix files"
      echo "  task clean      - Clean old generations"
      echo ""
      echo "📝 Project: $(pwd)"
      echo "🌿 Git branch: $(git branch --show-current 2>/dev/null || echo 'not in git repo')"
      
      # Set up useful aliases that don't override standard commands
      alias ll="eza -la --icons"
      alias la="eza -a --icons"
      alias lt="eza --tree --icons"
      
      # Suggest using the modern tools without forcing them
      echo ""
      echo "💡 Modern CLI tools available:"
      echo "  • 'eza' for better ls (alias: ll, la, lt)"
      echo "  • 'bat' for syntax-highlighted cat"
      echo "  • 'fd' for faster find"
      echo "  • 'rg' for faster grep (ripgrep)"
    '';
  };

  # TypeScript/JavaScript development shell
  typescript = pkgs.mkShell {
    name = "typescript-dev";
    buildInputs = with pkgs; [
      nodejs_22
      nodePackages.pnpm
      nodePackages.yarn
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodePackages.eslint
      nodePackages.prettier
      bun
      deno
    ];

    shellHook = ''
      echo "TypeScript Development Environment"
      echo "Node: $(node --version)"
      echo "PNPM: $(pnpm --version)"
      echo "TypeScript: $(tsc --version)"
      export PATH="$PWD/node_modules/.bin:$PATH"
    '';
  };

  # Python development shell
  python = pkgs.mkShell {
    name = "python-dev";
    buildInputs = with pkgs; [
      python312
      python312Packages.pip
      python312Packages.virtualenv
      python312Packages.setuptools
      python312Packages.wheel
      python312Packages.pytest
      python312Packages.black
      python312Packages.flake8
      python312Packages.mypy
      python312Packages.ipython
      python312Packages.jupyter
      poetry
      ruff
      pyright
    ];

    shellHook = ''
      echo "Python Development Environment"
      echo "Python: $(python --version)"
      echo "Poetry: $(poetry --version)"
      
      # Create virtual environment if it doesn't exist
      if [ ! -d .venv ]; then
        echo "Creating virtual environment..."
        python -m venv .venv
      fi
      source .venv/bin/activate
    '';
  };

  # Rust development shell
  rust = pkgs.mkShell {
    name = "rust-dev";
    buildInputs = with pkgs; [
      rustc
      cargo
      rustfmt
      rust-analyzer
      clippy
      cargo-watch
      cargo-edit
      cargo-outdated
      cargo-audit
      cargo-bloat
      cargo-expand
      sccache
    ];

    shellHook = ''
      echo "Rust Development Environment"
      echo "Rust: $(rustc --version)"
      echo "Cargo: $(cargo --version)"
      export RUST_BACKTRACE=1
      export RUST_SRC_PATH="${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}"
    '';
  };

  # Go development shell
  go = pkgs.mkShell {
    name = "go-dev";
    buildInputs = with pkgs; [
      go
      gopls
      go-tools
      golangci-lint
      delve
      gomodifytags
      gotests
      impl
      gocode-gomod
    ];

    shellHook = ''
      echo "Go Development Environment"
      echo "Go: $(go version)"
      export GOPATH="$HOME/go"
      export PATH="$GOPATH/bin:$PATH"
    '';
  };

  # C/C++ development shell
  cpp = pkgs.mkShell {
    name = "cpp-dev";
    buildInputs = with pkgs; [
      gcc
      clang
      cmake
      ninja
      meson
      pkg-config
      gdb
      lldb
      # valgrind  # Broken on macOS
      clang-tools
      cppcheck
      doxygen
      boost
      catch2
    ];

    shellHook = ''
      echo "C/C++ Development Environment"
      echo "GCC: $(gcc --version | head -n1)"
      echo "Clang: $(clang --version | head -n1)"
      echo "CMake: $(cmake --version | head -n1)"
    '';
  };

  # DevOps shell
  devops = pkgs.mkShell {
    name = "devops";
    buildInputs = with pkgs; [
      # Cloud tools
      awscli2
      google-cloud-sdk
      azure-cli
      doctl

      # Kubernetes
      kubectl
      kubernetes-helm
      k9s
      kind
      minikube
      kustomize
      kubeseal

      # Infrastructure as Code
      terraform
      terragrunt
      packer
      ansible
      pulumi

      # CI/CD
      github-cli
      # gitlab  # Linux-only
      # jenkins  # Platform-specific

      # Container tools
      docker-compose
      podman
      # buildah  # May have platform issues
      skopeo
      dive

      # Monitoring  
      # prometheus  # Server app, may have issues
      # grafana  # Server app, may have issues
      # telegraf  # May have platform issues
    ];

    shellHook = ''
      echo "DevOps Environment"
      echo "Terraform: $(terraform version | head -n1)"
      echo "Kubectl: $(kubectl version --client --short)"
      echo "Docker: $(docker --version)"
    '';
  };

  # Database development shell
  database = pkgs.mkShell {
    name = "database-dev";
    buildInputs = with pkgs; [
      postgresql
      mysql80
      redis
      mongodb
      sqlite

      # Clients
      pgcli
      mycli
      litecli
      mongosh
      redis

      # Migration tools
      flyway
      liquibase
      dbmate

      # GUI tools
      dbeaver-bin
      pgadmin4
    ];

    shellHook = ''
      echo "Database Development Environment"
      echo "PostgreSQL: $(psql --version)"
      echo "MySQL: $(mysql --version)"
      echo "Redis: $(redis-cli --version)"
    '';
  };

  # Data science shell
  datascience = pkgs.mkShell {
    name = "datascience";
    buildInputs = with pkgs; [
      # Python with data science packages
      (python312.withPackages (ps: with ps; [
        numpy
        pandas
        scipy
        scikit-learn
        matplotlib
        seaborn
        plotly
        jupyterlab
        notebook
        ipython
        statsmodels
        pytorch
        tensorflow
        keras
        xgboost
        lightgbm
      ]))

      # R environment
      R
      # rstudio  # GUI app, platform-specific

      # Julia - Linux-only
      # julia

      # Tools
      quarto
    ];

    shellHook = ''
      echo "Data Science Environment"
      echo "Python with ML/DS packages loaded"
      echo "R: $(R --version | head -n1)"
      echo "Julia: $(julia --version)"
      jupyter lab
    '';
  };

  # Mobile development shell
  mobile = pkgs.mkShell {
    name = "mobile-dev";
    buildInputs = with pkgs; [
      # React Native
      nodejs_22
      # nodePackages.react-native-cli # Deprecated, use npx react-native instead
      # nodePackages.expo-cli # Use npx expo instead
      watchman

      # Flutter
      flutter

      # Android
      # android-studio # Large package, install separately if needed
      android-tools

      # Tools
      scrcpy
      # cocoapods # macOS specific
    ];

    shellHook = ''
      echo "Mobile Development Environment"
      echo "React Native CLI available"
      echo "Flutter: $(flutter --version | head -n1)"
      export ANDROID_HOME="$HOME/Android/Sdk"
      export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH"
    '';
  };

  # Security testing shell
  security = pkgs.mkShell {
    name = "security";
    buildInputs = with pkgs; [
      # Network tools
      nmap
      # masscan  # Linux-only (requires glibc)
      # zmap  # Marked as broken in nixpkgs
      netcat
      socat
      tcpdump
      # wireshark  # GUI app, platform-specific

      # Web security
      # burpsuite  # GUI app, platform-specific
      # zap  # GUI app, platform-specific
      nikto
      sqlmap
      gobuster
      ffuf
      # wfuzz  # May have Linux dependencies

      # Vulnerability scanners
      # metasploit  # Linux-only (requires glibc)
      nuclei
      trivy
      grype

      # Password tools
      hashcat
      john
      # hydra  # May have Linux dependencies

      # Forensics
      binwalk
      # foremost  # Linux-only
      # volatility3  # May have Linux dependencies

      # Crypto
      openssl
      gnupg
    ];

    shellHook = ''
      echo "Security Testing Environment"
      echo "⚠️  Use responsibly and only on systems you own or have permission to test"
      echo "Nmap: $(nmap --version | head -n1)"
    '';
  };
}
