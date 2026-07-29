# AI Offensive Workstation portable Zsh configuration.
# Loaded system-wide for every interactive Zsh user.
# No hardcoded username, home directory, target, or credential is used.
# Credentials belong only in the ignored project .env and are injected by
# Docker Compose. Never store secrets in this tracked shell configuration.

[[ -o interactive ]] || return

# The same managed configuration is present in the system and standard user
# locations. Prevent duplicate Oh My Zsh initialization when both are loaded.
[[ "${AI_OFFENSIVE_ZSH_LOADED:-0}" == 1 ]] && return
typeset -gx AI_OFFENSIVE_ZSH_LOADED=1

# -----------------------------------------------------------------------------
# Shell behavior
# -----------------------------------------------------------------------------
setopt autocd
setopt interactivecomments
setopt magicequalsubst
setopt nonomatch
setopt notify
setopt numericglobsort
setopt promptsubst

WORDCHARS='_-'
PROMPT_EOL_MARK=''

# -----------------------------------------------------------------------------
# Key bindings
# -----------------------------------------------------------------------------
bindkey -e
bindkey ' ' magic-space
bindkey '^U' backward-kill-line
bindkey '^[[3;5~' kill-word
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[5~' beginning-of-buffer-or-history
bindkey '^[[6~' end-of-buffer-or-history
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[Z' undo

# -----------------------------------------------------------------------------
# Cache, completion, history, and Oh My Zsh
# -----------------------------------------------------------------------------
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
typeset -g ZSH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p -- "$ZSH_CACHE_DIR" "$ZSH_STATE_DIR" 2>/dev/null

HISTFILE="$ZSH_STATE_DIR/history"
HISTSIZE=10000
SAVEHIST=10000

setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_verify

alias history='fc -l 1'

TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# Oh My Zsh is installed once in the immutable image and shared by root and
# Hermes. The custom prompt below intentionally replaces an Oh My Zsh theme.
typeset -g ZSH=/opt/oh-my-zsh
typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump"
ZSH_THEME=''
plugins=(git)
DISABLE_AUTO_UPDATE=true
DISABLE_UPDATE_PROMPT=true
ZSH_DISABLE_COMPFIX=true
zstyle ':omz:update' mode disabled

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit
  compinit -i -d "$ZSH_COMPDUMP"
fi

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*' list-prompt '%SAt %p: press TAB for more, or type a character%s'
zstyle ':completion:*' select-prompt '%SScrolling: selection %p%s'

# -----------------------------------------------------------------------------
# PATH
# -----------------------------------------------------------------------------
typeset -U path PATH
for candidate_dir in \
  "$HOME/.local/bin" \
  "$HOME/.npm-global/bin" \
  /workspace/bin \
  /workspace/scripts \
  /usr/local/go/bin \
  /opt/toolchains/node/bin \
  /opt/toolchains/go/bin \
  /opt/toolchains/python/bin \
  /opt/toolchains/cargo/bin \
  /opt/browser-tools/playwright/node_modules/.bin
do
  [[ -d "$candidate_dir" ]] && path=("$candidate_dir" $path)
done
export PATH
unset candidate_dir

# -----------------------------------------------------------------------------
# Prompt
# PROMPT_MODE may be "twoline" or "oneline". Ctrl+P toggles it.
# -----------------------------------------------------------------------------
autoload -Uz colors && colors

: "${PROMPT_MODE:=twoline}"

configure_prompt() {
  local virtualenv_prompt=''

  if [[ -n "$VIRTUAL_ENV" ]]; then
    virtualenv_prompt=" %F{yellow}(${VIRTUAL_ENV:t})%f"
  fi

  case "$PROMPT_MODE" in
    oneline)
      PROMPT="%F{cyan}%n@%m%f:%F{blue}%~%f${virtualenv_prompt} %(?.%F{green}.%F{red})%#%f "
      ;;
    twoline|*)
      PROMPT="%F{cyan}%n@%m%f %F{blue}%~%f${virtualenv_prompt}"$'\n'"%(?.%F{green}.%F{red})%#%f "
      ;;
  esac

  RPROMPT='%(?..%F{red}exit:%?%f)'
}

configure_prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1

autoload -Uz add-zsh-hook
add-zsh-hook precmd configure_prompt

toggle_prompt() {
  if [[ "$PROMPT_MODE" == oneline ]]; then
    PROMPT_MODE=twoline
  else
    PROMPT_MODE=oneline
  fi

  configure_prompt
  zle reset-prompt
}

zle -N toggle_prompt
bindkey '^P' toggle_prompt

# -----------------------------------------------------------------------------
# Terminal title
# -----------------------------------------------------------------------------
autoload -Uz add-zsh-hook

set_terminal_title() {
  case "$TERM" in
    xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty*|screen*|tmux*)
      print -Pn '\e]0;%n@%m: %~\a'
      ;;
  esac
}

add-zsh-hook precmd set_terminal_title

# -----------------------------------------------------------------------------
# Colors, aliases, and helpers
# -----------------------------------------------------------------------------
if (( $+commands[dircolors] )); then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi

  export LS_COLORS="${LS_COLORS}:ow=30;44:"
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

if command ls --color=auto -d . >/dev/null 2>&1; then
  alias ls='ls --color=auto'
elif [[ "$OSTYPE" == darwin* || "$OSTYPE" == freebsd* ]]; then
  alias ls='ls -G'
fi

if command grep --help 2>&1 | command grep -q -- '--color'; then
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

if command diff --help 2>&1 | command grep -q -- '--color'; then
  alias diff='diff --color=auto'
fi

alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

mkcd() {
  if (( $# != 1 )); then
    print -u2 'usage: mkcd DIRECTORY'
    return 2
  fi

  mkdir -p -- "$1" && cd -- "$1"
}

# -----------------------------------------------------------------------------
# Optional distro integrations and plugins
# -----------------------------------------------------------------------------
source_first_readable() {
  local plugin_file

  for plugin_file in "$@"; do
    if [[ -r "$plugin_file" ]]; then
      source "$plugin_file"
      return 0
    fi
  done

  return 1
}

source_first_readable \
  /etc/zsh_command_not_found \
  /etc/zsh/zsh_command_not_found \
  /usr/share/doc/command-not-found/examples/etc-zsh-command-not-found \
  >/dev/null 2>&1 || true

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#B2BEB5'

source_first_readable \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  >/dev/null 2>&1 || true

# Resolve the highlighting plugin first so helper cleanup happens before it.
# Zsh syntax highlighting must be the final sourced plugin.
typeset -g ZSH_SYNTAX_HIGHLIGHTING_FILE=''
for plugin_file in \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
do
  if [[ -r "$plugin_file" ]]; then
    ZSH_SYNTAX_HIGHLIGHTING_FILE="$plugin_file"
    break
  fi
done

unset -f source_first_readable
unset plugin_file

if [[ -n "$ZSH_SYNTAX_HIGHLIGHTING_FILE" ]]; then
  source "$ZSH_SYNTAX_HIGHLIGHTING_FILE"
fi
