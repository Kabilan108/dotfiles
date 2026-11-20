# shellcheck shell=bash
# vim: syn=bash ft=bash

case $- in
*i*) ;;
*) return ;;
esac

if [[ -n $SSH_TTY && -z $TMUX && -z $NO_TMUX ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi

shopt -s checkwinsize

PROMPT_DIRTRIM=2

bind Space:magic-space

shopt -s globstar 2>/dev/null

shopt -s nocaseglob

set -o vi

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

bind '"\C-l":"clear\n"'
bind '"\C-A-l":"clear\n"'

bind "set completion-ignore-case on"

bind "set show-all-if-ambiguous on"

bind "set mark-symlinked-directories on"

shopt -s histappend

shopt -s cmdhist

HISTSIZE=100000
HISTFILESIZE=100000

HISTCONTROL="erasedups:ignoreboth"

HISTTIMEFORMAT='%F %T '

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'

shopt -s dirspell 2>/dev/null

shopt -s cdspell 2>/dev/null

shopt -s cdable_vars

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
  local file
  file=$(fd --hidden --type f --exclude .git |
    fzf --height 40% --layout=reverse --border \
      --preview "bat --style=numbers --color=always {}") || return
  nvim -- "$file"
}

function agy() {
  local bin bus
  bin="$(type -P agy)" || {
    echo "agy: command not found" >&2
    return 127
  }
  bus="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
  if [[ -S "$bus" ]]; then
    env -u SSH_CONNECTION -u SSH_CLIENT -u SSH_TTY \
      DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$bus}" \
      "$bin" "$@"
  else
    "$bin" "$@"
  fi
}

rawssh() {
  ssh -t "$@" 'NO_TMUX=1 exec bash -il'
}

alias ta="tmuxa"
alias tn="tmuxn"
alias tl="tmuxl"
alias tk="tmuxk"

alias cc="claude --dangerously-skip-permissions"
alias cx="codex --yolo"
alias cc-cpa="claude-cpa --dangerously-skip-permissions"
alias cx-cpa="codex-cpa --yolo"
alias cxf="codex --yolo --model gpt-6.1-sol --config model_reasoning_effort=low --config service_tier=fast"
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
fi

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ -z "$TMUX" ] \
  && [ -z "$SSH_CONNECTION" ] && [ "$(tty)" = /dev/tty1 ]; then
  if command -v niri-session >/dev/null 2>&1; then
    exec niri-session
  fi
fi
