{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Node.js and package managers
    nodejs_22
    nodePackages.npm
    nodePackages.pnpm
    nodePackages.yarn
    corepack # Automatic package manager version management

    # TypeScript and language servers
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted

    # Linters and formatters
    nodePackages.eslint
    nodePackages.prettier
    biome

    # Build tools
    nodePackages.webpack
    nodePackages.webpack-cli

    # Development utilities
    nodePackages.nodemon
    nodePackages.npm-check-updates
    nodePackages.serve
    nodePackages.http-server

    # Alternative runtimes
    bun
    deno

    # Database clients
    nodePackages.prisma
    mongosh
    postgresql
    redis

    # API development
    insomnia
    httpie
  ];

  # Environment variables
  environment.sessionVariables = {
    PNPM_HOME = "$HOME/.local/share/pnpm";
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  # Shell aliases
  environment.shellAliases = {
    # Package managers
    ni = "pnpm install";
    nr = "pnpm run";
    nd = "pnpm run dev";
    nb = "pnpm run build";
    nt = "pnpm test";

    # Common tasks
    ncu = "npm-check-updates";
    tsc = "npx tsc";
    tsx = "npx tsx";
  };
}
