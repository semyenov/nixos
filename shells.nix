# Development Shells  
# Streamlined shell environments using functional composition

{ pkgs ? import <nixpkgs> { } }:

let
  inherit (pkgs) lib;

  # Base development environment
  mkDevShell = name: description: packages: extraHook: pkgs.mkShell {
    inherit name;
    buildInputs = with pkgs; [
      # Core tools
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
    ] ++ packages;

    shellHook = ''
      alias ll="eza -la --icons"; alias la="eza -a --icons"; alias lt="eza --tree --icons"
      echo "🚀 ${description}"
      echo "📝 $(pwd) | 🌿 $(git branch --show-current 2>/dev/null || echo 'no git')"
      ${extraHook}
    '';
  };

  # Package sets
  nixosTools = with pkgs; [ nixpkgs-fmt nil statix deadnix nix-tree nix-output-monitor go-task sops age ssh-to-age git-crypt mdbook pandoc ];
  webTools = with pkgs; [ nodejs_22 nodePackages.pnpm nodePackages.yarn nodePackages.typescript nodePackages.typescript-language-server nodePackages.eslint nodePackages.prettier bun deno ];
  systemsTools = with pkgs; [ rustc cargo rust-analyzer rustfmt clippy go gopls golangci-lint gcc clang cmake ninja gdb pkg-config ] ++ lib.optionals stdenv.isLinux [ valgrind ];
  opsTools = with pkgs; [ python311 python311Packages.pip python311Packages.virtualenv python311Packages.jupyter python311Packages.pandas python311Packages.numpy python311Packages.matplotlib docker docker-compose kubectl terraform ansible postgresql sqlite redis prometheus grafana ] ++ lib.optionals stdenv.isLinux [ helm ];
  mobileTools = with pkgs; [ flutter android-tools nmap wireshark tcpdump openssl gnupg pass netcat socat curl wget ] ++ lib.optionals (stdenv.system == "x86_64-linux") [ android-studio ];
in
{
  nixos = mkDevShell "nixos-dev" "NixOS Configuration Development" nixosTools
    "echo 'Tools: nixpkgs-fmt, nil, statix, sops, task | Commands: task test | task rebuild | task format'";

  web = mkDevShell "web-dev" "Web Development Environment" webTools
    "echo 'Node: $(node --version) | TypeScript: $(tsc --version) | Runtimes: node, bun, deno'";

  systems = mkDevShell "systems-dev" "Systems Programming Environment" systemsTools
    "echo '🦀 Rust: $(rustc --version | cut -d\\\" \\\" -f2) | 🐹 Go: $(go version | cut -d\\\" \\\" -f3) | 🔧 C/C++: $(gcc --version | head -1 | cut -d\\\" \\\" -f3)'";

  ops = mkDevShell "ops-dev" "Data Science & DevOps Environment" opsTools
    "echo '🐍 Python: $(python --version) | 🐳 Docker: $(docker --version | cut -d\\\" \\\" -f3 | tr -d \\\",\\\") | Tools: kubectl, terraform, ansible, jupyter'";

  mobile = mkDevShell "mobile-dev" "Mobile Development & Security Environment" mobileTools
    "echo '📱 Flutter: $(flutter --version | head -1 | cut -d\\\" \\\" -f2) | 🔒 Security: nmap, wireshark, openssl | 📡 Network: netcat, socat, curl'";
}
