# Dotfiles

## Prerequisites

1. Install zsh (if not already installed):

   ```bash
   # macOS (using Homebrew)
   brew install zsh
   
   # Ubuntu/Debian
   sudo apt install zsh
   
   # Set as default shell
   chsh -s $(which zsh)
   ```

## Setup

Create symlinks for the configuration files (adjust the dotfiles path to wherever you cloned this repo):

```bash
# Zsh configuration
ln -s /path/to/your/dotfiles/zshrc ~/.zshrc

# Neovim configuration
ln -s /path/to/your/dotfiles/nvim ~/.config/nvim

# Wezterm configuration
ln -s /path/to/your/dotfiles/wezterm.lua ~/.wezterm.lua

# macOS window management (optional)
ln -s /path/to/your/dotfiles/macos/sketchybar ~/.config/sketchybar
ln -s /path/to/your/dotfiles/macos/yabairc ~/.yabairc
ln -s /path/to/your/dotfiles/macos/skhdrc ~/.skhdrc
```

After symlinking, restart your terminal or source the zsh config:

```bash
source ~/.zshrc
```

**Note:** The zsh configuration includes automatic tool checking that will show installation instructions for any missing dependencies when you start a new shell session.

