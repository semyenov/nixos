{ config, pkgs, inputs, ... }:

{
  # Home Manager configuration for semyenov
  home = {
    username = "semyenov";
    # homeDirectory is automatically set by NixOS

    # This value determines the Home Manager release
    stateVersion = "25.05";

    # Packages to install for this user
    packages = with pkgs; [
      # Communication (keep essentials)
      # thunderbird  # ~500 MB - use web email
      telegram-desktop # Keep for messaging
      # discord  # Temporarily disabled due to download issues
      # slack        # ~500 MB - use web version
      # zoom-us      # ~500 MB - use web version

      # Browsers (keep only one primary)
      brave # Primary browser
      # google-chrome  # ~1 GB - duplicate Chromium browser

      # Security
      gopass # Lightweight CLI tool
      gopass-jsonapi
      bitwarden
      keepassxc # Lightweight, good to have backup

      # Gaming (commented to save space)
      # lutris  # ~500 MB + Wine dependencies
      # steam   # ~2-3 GB + runtime dependencies
      # mangohud
      # gamemode

      # Development (keep only essential editors)
      code-cursor # Keep cursor for development
      claude-code # Keep claude-code for AI assistance
      # vscode       # ~1.5 GB - duplicate editor
      # jetbrains.idea-community  # ~2-3 GB - very heavy
      # postman      # Can use curl/httpie instead
      # dbeaver-bin  # ~500 MB - use CLI tools instead

      # Terminal emulators
      ghostty
      kitty # Lightweight, keep both
      # warp-terminal  # Heavy Electron-based terminal

      # Media
      vlc # Keep both media players
      mpv # Lightweight media player
      spotify
      # obs-studio   # ~500 MB - streaming software
      # kdePackages.kdenlive  # ~1-2 GB with Qt6/KDE libs
      # gimp         # ~500 MB - heavy image editor
      # inkscape     # ~500 MB - heavy vector editor

      # Office (minimize heavy packages)
      # libreoffice  # ~1.5 GB - use web office or lighter editors
      obsidian # Keep for notes
      # logseq       # Duplicate note-taking app
      # zotero       # Academic reference manager

      # Utilities
      flameshot # Lightweight screenshot tool
      peek # Lightweight GIF recorder
      kooha # Screen recorder
      wl-clipboard # Lightweight clipboard utils
      xclip # Lightweight clipboard utils
    ];

    # Session variables with proper PATH handling
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "brave";
      TERMINAL = "ghostty";

      # Development
      PNPM_HOME = "$HOME/.local/share/pnpm";
      NPM_CONFIG_PREFIX = "$HOME/.npm-global";

      # Wayland support for Electron apps
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";

      # Additional development variables
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
      GOPATH = "$HOME/go";
    };

    # Properly manage PATH
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.npm-global/bin"
      "$HOME/.local/share/pnpm"
      "$HOME/.cargo/bin"
      "$HOME/go/bin"
    ];

    # File associations
    file = {
      ".gitconfig".text = ''
        [user]
          name = Alexander Semyenov
          email = semyenov@hotmail.com
        
        [core]
          editor = nvim
          autocrlf = input
          whitespace = trailing-space,space-before-tab
        
        [init]
          defaultBranch = main
        
        [pull]
          rebase = true
        
        [fetch]
          prune = true
        
        [diff]
          colorMoved = zebra
        
        [merge]
          conflictStyle = diff3
        
        [rerere]
          enabled = true
      '';

      ".config/ghostty/config".text = ''
        font-family = JetBrains Mono
        font-size = 14
        cursor-style = block
        background-opacity = 0.95
        window-decoration = true
        clipboard-read = allow
        clipboard-write = allow
        clipboard-paste-protection = true
        bold-is-bright = false
      '';
    };
  };

  # Program configurations
  programs = {
    # Enable Home Manager
    home-manager.enable = true;

    # Git
    git = {
      enable = true;
      userName = "Alexander Semyenov";
      userEmail = "semyenov@hotmail.com";

      delta = {
        enable = true;
        options = {
          navigate = true;
          light = false;
          side-by-side = true;
          line-numbers = true;
        };
      };

      extraConfig = {
        core.editor = "nvim";
        init.defaultBranch = "main";
        pull.rebase = true;
      };

      aliases = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
    };

    # ZSH
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 100000;
        save = 100000;
        path = "$HOME/.zsh_history";
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
      };

      initContent = ''
        # Load completions
        autoload -Uz compinit && compinit
        
        # Better history search
        bindkey '^R' history-incremental-search-backward
        bindkey '^S' history-incremental-search-forward
        
        # Better word navigation
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word
        
        # Auto-suggest accept
        bindkey '^ ' autosuggest-accept
      '';

      shellAliases = {
        # System
        rebuild = "task rebuild";
        update = "task update";
        clean = "task clean";

        # Navigation
        ll = "eza -la --icons";
        ls = "eza --icons";
        la = "eza -a --icons";
        lt = "eza --tree --icons";
        cd = "z";

        # Git
        g = "git";
        gs = "git status";
        gc = "git commit";
        gp = "git push";
        gl = "git pull";
        gd = "git diff";
        ga = "git add";

        # Development
        v = "nvim";
        c = "code";
        cursor-x11 = "ELECTRON_OZONE_PLATFORM_HINT=x11 cursor";
        cursor-wayland = "ELECTRON_OZONE_PLATFORM_HINT=wayland cursor";

        # Docker
        d = "docker";
        dc = "docker-compose";
        dps = "docker ps";

        # Package managers
        ni = "pnpm install";
        nr = "pnpm run";
        nd = "pnpm run dev";
        nb = "pnpm run build";
        nt = "pnpm test";
      };
    };

    # Starship prompt
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = "$all$character";
        add_newline = true;

        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };

        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
        };

        git_branch = {
          symbol = "🌱 ";
        };

        nodejs = {
          symbol = "⬢ ";
        };

        package = {
          disabled = false;
        };
      };
    };

    # Direnv
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # FZF
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
      ];
    };

    # Zoxide
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # Bat
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        pager = "less -FR";
      };
    };

    # Eza
    eza = {
      enable = true;
      icons = "auto";
      git = true;
    };

    # Neovim
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      plugins = with pkgs.vimPlugins; [
        # Theme
        tokyonight-nvim

        # Core
        nvim-treesitter.withAllGrammars
        telescope-nvim
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        luasnip

        # UI
        lualine-nvim
        nvim-tree-lua
        bufferline-nvim
        gitsigns-nvim

        # Utilities
        comment-nvim
        nvim-autopairs
        which-key-nvim
        toggleterm-nvim
      ];
    };
  };

  # GNOME configuration
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
      clock-show-seconds = true;
      clock-show-weekday = true;
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      repeat-interval = 30;
      delay = 250;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
      speed = 0.0;
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      focus-mode = "click";
    };

    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "dash-to-dock@micxgx.gmail.com"
        "blur-my-shell@aunetx"
        "Vitals@CoreCoding.com"
        "caffeine@patapon.info"
        "clipboard-indicator@tudmotu.com"
      ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      dock-fixed = true;
      extend-height = false;
      dash-max-icon-size = 48;
      show-trash = false;
      show-mounts = false;
      custom-theme-shrink = true;
      transparency-mode = "DYNAMIC";
      background-opacity = 0.8;
    };
  };

  # Services
  services = {
    # GPG agent
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      defaultCacheTtl = 86400;
      maxCacheTtl = 172800;
      pinentry.package = pkgs.pinentry-gnome3;
    };

    # Syncthing
    syncthing = {
      enable = false; # Enable if needed
    };
  };

  # XDG configuration
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      publicShare = "$HOME/Public";
      templates = "$HOME/Templates";
      videos = "$HOME/Videos";
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
        "application/pdf" = "org.gnome.Evince.desktop";
        "image/*" = "org.gnome.eog.desktop";
        "video/*" = "mpv.desktop";
        "audio/*" = "mpv.desktop";
      };
    };
  };
}
