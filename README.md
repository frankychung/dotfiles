# Dotfiles

## Setup

Create symlinks (adjust the dotfiles path as needed):

```bash
# Zsh
ln -s ~/dev/dotfiles/zshrc ~/.zshrc

# Neovim (MiniMax config for nvim 0.12+)
ln -s ~/dev/dotfiles/nvim ~/.config/nvim

# tmux
ln -s ~/dev/dotfiles/tmux.conf ~/.tmux.conf

# WezTerm
ln -s ~/dev/dotfiles/wezterm.lua ~/.wezterm.lua

# Claude Code statusline
ln -s ~/dev/dotfiles/.claude/statusline-command.sh ~/.claude/statusline-command.sh

# macOS only
ln -s ~/dev/dotfiles/macos/paneru.toml ~/.paneru.toml
ln -s ~/dev/dotfiles/macos/sketchybar ~/.config/sketchybar
```

## What's Included

- **zshrc** — Zsh config with vi mode, history, and automatic tool-check on startup
- **nvim/** — Neovim config using MiniMax (mini.nvim based)
- **tmux.conf** — tmux configuration
- **wezterm.lua** — WezTerm terminal config
- **.claude/statusline-command.sh** — Claude Code statusline (cost, token bar, rate limit, model, branch, dir)
- **macos/** — macOS-specific configs:
  - **paneru.toml** — Paneru window manager
  - **sketchybar/** — status bar
  - `*.bak` — archived configs (aerospace, yabai, skhd)

