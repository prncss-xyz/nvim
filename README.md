# Neovim configuration

## System dependencies

YAML frontmatter support uses `lyaml` when it is available and falls back to the
`yq` command-line tool. The personal configuration installs `lyaml` through
Lazy.nvim; the work configuration only requires `yq`. Both the kislyuk and Mike
Farah implementations of `yq` are supported.

### Void Linux

```sh
sudo xbps-install -S base-devel libyaml-devel readline-devel yq
```

`yq` is only needed as a fallback if `lyaml` cannot be built or loaded.

### macOS

```sh
brew install yq
```
