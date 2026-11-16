test -f /usr/share/cachyos-fish-config/cachyos-config.fish; and source /usr/share/cachyos-fish-config/cachyos-config.fish

set -g fish_greeting
fish_add_path -g ~/.local/bin
test -S ~/.1password/agent.sock; and set -gx SSH_AUTH_SOCK ~/.1password/agent.sock

# Homebrew
test -x /home/linuxbrew/.linuxbrew/bin/brew; and eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)"

if status is-interactive
    # Starship custom prompt
    command -v starship &> /dev/null; and starship init fish | source

    # Direnv + Zoxide + fzf
    command -v direnv &> /dev/null; and direnv hook fish | source
    command -v zoxide &> /dev/null; and zoxide init fish --cmd cd | source
    command -v fzf &> /dev/null; and fzf --fish | source

    # List Directory (lsd)
    if command -v lsd &> /dev/null
        alias ls='lsd'
        alias l='ls -l'
        alias la='ls -a'
        alias lla='ls -la'
        alias lt='ls --tree'
    end

    # Handy change dir shortcuts
    abbr .. 'cd ..'
    abbr ... 'cd ../..'
    abbr .3 'cd ../../..'
    abbr .4 'cd ../../../..'
    abbr .5 'cd ../../../../..'
    abbr mkdir 'mkdir -p'

    # Git abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    # Fixes "Error opening terminal: xterm-kitty" when using kitty ssh
    alias ssh='kitten ssh'

    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end

# Editor
set -gx EDITOR nvim

# bun
set -gx BUN_INSTALL "$HOME/.bun"
test -d "$BUN_INSTALL/bin"; and fish_add_path -g "$BUN_INSTALL/bin"

# Android emulator
set -gx ANDROID_HOME "$HOME/Android/Sdk"
test -d "$ANDROID_HOME/emulator"; and fish_add_path -g "$ANDROID_HOME/emulator"
test -d "$ANDROID_HOME/platform-tools"; and fish_add_path -g "$ANDROID_HOME/platform-tools"

# Java
test -d /usr/lib/jvm/java-17-openjdk; and set -gx JAVA_HOME "/usr/lib/jvm/java-17-openjdk"; and fish_add_path -g "$JAVA_HOME/bin"

# .NET Core SDK tools
test -d "$HOME/.dotnet/tools"; and fish_add_path -g "$HOME/.dotnet/tools"

# Flutter & Dart
set -gx CHROME_EXECUTABLE "/usr/bin/google-chrome-stable"
test -d "$HOME/fvm/default/bin"; and fish_add_path -g "$HOME/fvm/default/bin"

# n
set -gx N_PREFIX "$HOME/.n"
test -d "$N_PREFIX/bin"; and fish_add_path -g "$N_PREFIX/bin"

# Agentes.chat
set -gx AGENTS_CHAT_PREFIX "$HOME/.agentes-runner"
test -d "$AGENTS_CHAT_PREFIX/bin"; and fish_add_path -g "$AGENTS_CHAT_PREFIX/bin"
