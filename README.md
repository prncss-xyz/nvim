# Neovim configuration

## System dependencies

YAML frontmatter support uses `lyaml`. Lazy.nvim builds it with LuaRocks through
Hererocks, so a C toolchain and the development headers for LibYAML and readline
must be available.

### Void Linux

```sh
sudo xbps-install -S base-devel libyaml-devel readline-devel
```

### macOS

Install the Xcode command-line tools and required libraries:

```sh
xcode-select --install
brew install libyaml readline
```

After installing the dependencies, run `:Lazy sync` in Neovim.
