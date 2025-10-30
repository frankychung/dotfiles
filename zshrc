# ================================
# Environment & Settings
# ================================
export LANG=en_US.UTF-8
export EDITOR="nvim"

# History
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000

# Options
bindkey -v
bindkey "^R" history-incremental-search-backward

# ================================
# PATH Configuration
# ================================
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Platform-specific paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS paths
    export PATH="$PATH:/Users/franky/bin:/Users/franky/.dotnet/tools"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux paths
    export PATH="$PATH:/home/franky/bin"
fi

export PATH="$PATH:$HOME/.local/bin"

# ================================
# Tool Configuration
# ================================

# Check for required tools and show install instructions
_check_tool() {
    local tool=$1
    local install_cmd_mac=$2
    local install_cmd_debian=$3
    
    if ! command -v "$tool" &>/dev/null; then
        echo "⚠️  $tool not found. Install with:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "   $install_cmd_mac"
        else
            echo "   $install_cmd_debian"
        fi
        return 1
    fi
    return 0
}

# Check for essential tools
_check_tool "git" "brew install git" "sudo apt install git"  
_check_tool "nvim" "brew install neovim" "curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage && chmod u+x nvim.appimage && mkdir -p ~/bin && mv nvim.appimage ~/bin/nvim && echo 'See: https://github.com/neovim/neovim/releases'"
_check_tool "curl" "brew install curl" "sudo apt install curl"
_check_tool "wezterm" "brew install --cask wezterm-nightly" "curl -fsSL https://apt.fury.io/wez/gpg.key | sudo apt-key add - && echo 'deb https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list && sudo apt update && sudo apt install wezterm-nightly"

# Database tools
# _check_tool "mysql" "brew install mysql" "sudo apt install mysql-server"
# _check_tool "psql" "brew install postgresql" "sudo apt install postgresql postgresql-contrib"
_check_tool "mycli" "brew install mycli" "pip install --user mycli"
_check_tool "pgcli" "brew install pgcli" "pip install --user pgcli"

# Platform-specific tools
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &>/dev/null; then
        echo "⚠️  Homebrew not found. Install with:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
    
    # Container tools (macOS only)
    _check_tool "docker-compose" "brew install --cask orbstack" "# Not needed on Linux"
else
    # Check for build tools on Linux
    if ! dpkg -l | grep -q build-essential; then
        echo "⚠️  build-essential not found. Install with:"
        echo "   sudo apt install build-essential"
    fi
fi

# To add new tool checks:
# _check_tool "toolname" "brew install toolname" "sudo apt install toolname"

# FZF with ripgrep
if [[ ! -f ~/.fzf.zsh ]]; then
    echo "⚠️  FZF shell integration not found. Install with:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   brew install fzf && \$(brew --prefix)/opt/fzf/install"
    else
        echo "   sudo apt install fzf"
        echo "   # Then run: /usr/share/doc/fzf/examples/key-bindings.zsh >> ~/.fzf.zsh"
    fi
fi
if _check_tool "rg" "brew install ripgrep" "sudo apt install ripgrep"; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Zoxide (replaces fasd)
if _check_tool "zoxide" "brew install zoxide" "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"; then
    eval "$(zoxide init zsh)"
fi

# Pure prompt
if [[ -d "$HOME/.zsh/pure" ]]; then
    fpath+=($HOME/.zsh/pure)
    autoload -U promptinit; promptinit
    prompt pure
else
    echo "⚠️  Pure prompt not found. Install with:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   npm install --global pure-prompt"
        echo "   # OR: git clone https://github.com/sindresorhus/pure.git ~/.zsh/pure"
    else
        echo "   npm install --global pure-prompt"
        echo "   # OR: git clone https://github.com/sindresorhus/pure.git ~/.zsh/pure"
    fi
fi

# NVM - load and use default synchronously (needed for global packages)
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm use default --silent 2>/dev/null || true
else
    _check_tool "nvm" "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash" "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
fi

# ================================
# Completions
# ================================
if type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
    autoload -Uz compinit
    
    # Only run compinit once per day for speed
    if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
        compinit
    else
        compinit -C
    fi
fi

# ================================
# Aliases
# ================================

# Modern file listing (eza/exa)
if command -v eza &>/dev/null; then
    alias ls="eza --color=always --group-directories-first"
    alias ll="eza -la --color=always --group-directories-first"
    alias la="eza -a --color=always --group-directories-first"
    alias lt="eza --tree --color=always"
    alias l="eza -F --color=always --group-directories-first"
elif command -v exa &>/dev/null; then
    alias ls="exa --color=always --group-directories-first"
    alias ll="exa -la --color=always --group-directories-first"
    alias la="exa -a --color=always --group-directories-first"
    alias lt="exa --tree --color=always"
    alias l="exa -F --color=always --group-directories-first"
else
    echo "⚠️  Modern ls replacement not found. Install with:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   brew install eza"
    else
        echo "   sudo apt install exa"
    fi
fi

# Better cat with syntax highlighting
if command -v bat &>/dev/null; then
    alias cat="bat --style=auto"
    alias less="bat --style=auto --paging=always"
elif command -v batcat &>/dev/null; then
    # Debian installs as batcat, create alias
    alias bat="batcat"
    alias cat="batcat --style=auto"
    alias less="batcat --style=auto --paging=always"
else
    echo "⚠️  bat not found. Install with:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   brew install bat"
    else
        echo "   sudo apt install bat"
    fi
fi

# Better find
if _check_tool "fd" "brew install fd" "sudo apt install fd-find"; then
    alias find="fd"
elif command -v fd-find &>/dev/null; then
    # Debian installs as fd-find, create alias
    alias fd="fd-find"
    alias find="fd-find"
fi


# Zoxide aliases (if available)
if command -v zoxide &>/dev/null; then
    alias cd="z"
fi

PATH="/Users/franky/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/Users/franky/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/Users/franky/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/Users/franky/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/Users/franky/perl5"; export PERL_MM_OPT;
