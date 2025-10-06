#!/usr/bin/env sh
# Install all packges needed by the plugins and language servers
source /etc/os-release
if [ "$ID" == "arch" ]; then
  sudo pacman --needed -Sy base-devel fd go jre21-openjdk-headless neovim npm ripgrep rust yazi
fi
# Install Mason packages I use the most
nvim --headless -c 'MasonInstall eslint-lsp json-lsp prettierd ltex-ls lua-language-server marksman stylua vtsls yaml-language-server' -c qall
