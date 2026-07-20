# vim: syn=bash ft=bash

# if not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# Interactive ssh terminals land in a persistent tmux session. Remote tools
# may start an interactive login shell without allocating a terminal.
if [[ -n $SSH_TTY && -z $TMUX && -z $NO_TMUX ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi

### -> GENERAL SETTINGS

# update window size after each command
shopt -s checkwinsize

# trim long paths in the prompt
PROMPT_DIRTRIM=2

# enable history expansion; typing '!!<space>' inserts last command
bind Space:magic-space

# recursive file globbing
shopt -s globstar 2>/dev/null

# case-insensitive path expansion
shopt -s nocaseglob

# vim mode
set -o vi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# enable CTRL+L and CTRL+Alt+L to clear terminal
bind '"\C-l":"clear\n"'
bind '"\C-A-l":"clear\n"'

### -> SMARTER TAB-COMPLETION

# case insensitive file completion
bind "set completion-ignore-case on"

# show matches for ambiguous patters on first tab press
bind "set show-all-if-ambiguous on"

# add trailing slash when autocompleting symlinks to directories
bind "set mark-symlinked-directories on"

### -> HISTORY DEFAULTS

# append to history file, dont overwrite
shopt -s histappend

# save multi-line commands as one command
shopt -s cmdhist

# huge history
HISTSIZE=100000
HISTFILESIZE=100000

# avoid duplicate entries
HISTCONTROL="erasedups:ignoreboth"

# use ISO8601 timestamp
# %F = '%Y-%m-%d'
# %T = '%H:%M:%S'
HISTTIMEFORMAT='%F %T '

# incremental history search
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'

### -> DIRECTORY NAVIGATION

# correct spelling errors during tab-completion
shopt -s dirspell 2>/dev/null

# correct spelling errors in args to cd
shopt -s cdspell 2>/dev/null

# this allows you to bookmark locations by setting variables to folder paths
shopt -s cdable_vars

### -> PROMPT

__bash_prompt() {
  local exit_code=$1
  local branch
  local arrow='\[\033[0m\]➜'
  local gitbranch=''

  if [ "$exit_code" -ne 0 ]; then
    arrow='\[\033[1;31m\]➜'
  fi

  branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null) || branch=''

  if [ -n "$branch" ]; then
    gitbranch="\[\033[0;36m\](\[\033[1;31m\]${branch}"

    if git --no-optional-locks ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" >/dev/null 2>&1; then
      gitbranch="${gitbranch} \[\033[1;33m\]✗"
    fi

    gitbranch="${gitbranch}\[\033[0;36m\]) "
  fi

  PS1="\[\033[0;32m\]${USER}\[\033[${FLEET_HOST_ANSI:-0;36}m\]@${HOSTNAME} ${arrow} \[\033[1;34m\]\w ${gitbranch}\[\033[0m\]\n\\$ "
}

__bash_prompt_command() {
  local exit_code=$?
  history -a
  __bash_prompt "$exit_code"
}

__repair_bash_preexec() {
  declare -F __bp_preexec_invoke_exec >/dev/null 2>&1 || return

  local install_snippet=$'__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'
  local prompt_command_decl
  prompt_command_decl=$(declare -p PROMPT_COMMAND 2>/dev/null)

  if [[ $prompt_command_decl == "declare -a"* ]]; then
    local repaired_prompt_command=()
    local command

    for command in "${PROMPT_COMMAND[@]}"; do
      command=${command//$install_snippet/}
      command=${command%$'\n'}
      [[ -n "$command" ]] && repaired_prompt_command+=("$command")
    done

    PROMPT_COMMAND=("${repaired_prompt_command[@]}")
  elif [[ -n ${PROMPT_COMMAND:-} ]]; then
    PROMPT_COMMAND=${PROMPT_COMMAND//$install_snippet/}
    PROMPT_COMMAND=${PROMPT_COMMAND%$'\n'}
  fi

  local debug_trap
  debug_trap=$(trap -p DEBUG)
  if [[ $debug_trap != *'__bp_preexec_invoke_exec'* ]]; then
    trap '__bp_preexec_invoke_exec "$_"' DEBUG
  fi
}

precmd() {
  __repair_bash_preexec
  __bash_prompt_command
}

__bash_prompt 0
export PROMPT_DIRTRIM=2

### -> ENVIRONMENT

if [ -f "$HOME/.bashenv" ]; then
  source "$HOME/.bashenv"
fi

### -> Shell integrations

eval "$(wt config shell init bash)"

#### --> FUNCTIONS

function tmuxa() {
  if [[ -z "$1" ]]; then
    echo "Usage: tmuxa <session>"
    return 1
  else
    tmux attach-session -t "$1"
  fi
}

function tmuxn() {
  if [[ -z "$1" ]]; then
    tmux new-session
  else
    tmux new-session -s "$1"
  fi
}

function tmuxl() {
  tmux list-sessions 2>/dev/null
}

function tmuxk() {
  if [[ -z "$1" ]]; then
    echo "Usage: tmuxk <session>"
    sessions=$(tmuxl | awk -F': ' '{print $1}' | paste -sd '  ' -)
    [ -n "$sessions" ] && echo "existing sessions:  $sessions"
    return 1
  else
    tmux kill-session -t "$1"
  fi
}

function fvi() {
  local file=$(fd --hidden --type f --exclude .git |
    fzf --height 40% --layout=reverse --border \
      --preview "bat --style=numbers --color=always {}") || return
  nvim -- "$file"
}

### -> ALIASES

# interactive ssh WITHOUT auto-attaching the remote tmux session
rawssh() {
  ssh -t "$@" 'NO_TMUX=1 exec bash -il'
}

alias ta="tmuxa"
alias tn="tmuxn"
alias tl="tmuxl"
alias tk="tmuxk"

alias cc="claude --dangerously-skip-permissions"
alias cx="codex --yolo"
alias oc="OPENCODE_EXPERIMENTAL=true opencode"

alias ls='ls --color=auto'
alias ll='ls -alF'
alias lha='ls -lha'
alias la='ls -A'
alias l='ls -CF'
alias lt="ls --human-readable --size -1 -S --classify"
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias lg='lazygit'
alias ipy='ipython'
alias icat='kitten icat'
alias nohist='HISTFILE=/dev/null'
alias svi='sudo -E nvim -u $HOME/.config/nvim/init.lua'
alias xlsx2csv='libreoffice --headless --convert-to csv'

if [ -n "$WAYLAND_DISPLAY" ]; then
  alias copy='wl-copy'
  alias clipboard='wl-paste'
elif [ -n "$DISPLAY" ]; then
  alias copy='xclip -selection clipboard'
  alias clipboard='xclip -selection clipboard -o'
fi

### -> AUTO-START HYPRLAND

# Auto-start compositor on TTY1
# - Only runs if not already in a graphical session ($DISPLAY check)
# - Only runs on TTY1 (preserves TTY2-6 for troubleshooting)
# - exec replaces shell process, so exiting the compositor logs you out cleanly
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ] && [ -z "$SSH_CONNECTION" ]; then
  if command -v niri-session >/dev/null 2>&1; then
    exec niri-session
  elif command -v Hyprland >/dev/null 2>&1; then
    exec Hyprland
  fi
fi
