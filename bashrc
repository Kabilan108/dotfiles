# bash defaults
#
# inspired by mrzool/bash-sensible
# version: 0.1

# if not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


### -> GENERAL SETTINGS

# update window size after each command
shopt -s checkwinsize

# trim long paths in the prompt
PROMPT_DIRTRIM=2

# enable history expansion; typing '!!<space>' inserts last command
bind Space:magic-space

# recursive file globbing
shopt -s globstar 2> /dev/null

# case-insensitive path expansion
shopt -s nocaseglob

# vim mode
set -o vi

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# enable bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# enable CTRL+L and CTRL+Alt+L to clear terminal
bind '"\C-l":"clear\n"'
bind '"\C-A-l":"clear\n"'

# load environment variables
source $HOME/.bash_env


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

# record each line as it gets issued
PROMPT_COMMAND='history -a'

# huge history
HISTSIZE=500000
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

# prepend cd to directory names automatically
shopt -s autocd 2> /dev/null

# correct spelling errors during tab-completion
shopt -s dirspell 2> /dev/null

# correct spelling errors in args to cd
shopt -s cdspell 2> /dev/null

# tell cd where to look for targets (add dirs separated by colons)
# e.g. CDPATH=".:~:~/projects" will look for targets in the cwd, home and ~/projects folders
CDPATH=".:~:/mnt/arrakis"

# this allows you to bookmark locations by setting variables to folder paths
shopt -s cdable_vars
export arrakis="/mnt/arrakis/"
export www="/var/www/"


### -> PROMPT

__bash_prompt() {
    local userpart='`export XIT=$? \
        && echo -n "\[\033[0;32m\]\u\[\033[0;36m\]@$HOSTNAME " \
        && [ "$XIT" -ne "0" ] && echo -n "\[\033[1;31m\]➜" || echo -n "\[\033[0m\]➜"`'
    local gitbranch='`\
        export BRANCH=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null); \
        if [ "${BRANCH}" != "" ]; then \
            echo -n "\[\033[0;36m\](\[\033[1;31m\]${BRANCH}" \
            && if git --no-optional-locks ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" > /dev/null 2>&1; then \
                echo -n " \[\033[1;33m\]✗"; \
            fi \
            && echo -n "\[\033[0;36m\]) "; \
        fi`'
    local lightblue='\[\033[1;34m\]'
    local removecolor='\[\033[0m\]'
    PS1="${userpart} ${lightblue}\w ${gitbranch}${removecolor}\n\$ "
    unset -f __bash_prompt
}
__bash_prompt
export PROMPT_DIRTRIM=4

### -> ENABLE PROGRAMS

# enable cuda
export PATH=/usr/local/cuda-12.6/bin${PATH:+:${PATH}}

# enable nvim
export PATH="$PATH:/opt/nvim-linux64/bin"

# enable cargo
source $HOME/.cargo/env

# enable nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # loads nvm bash_completion
EDITOR=nvim
VISUAL=$EDITOR

# enable bun
export BUN_INSTALL="$HOME/.bun"
export PATH=$BUN_INSTALL/bin:$PATH
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# enable cargo
. "$HOME/.cargo/env"

### -> ALIASES

alias nohist='HISTFILE=/dev/null'

# give things some color
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt="ls --human-readable --size -1 -S --classify"
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias fd="fdfind"

# editors
alias vi='nvim'
alias svi='sudo -E /opt/nvim-linux64/bin/nvim -u $HOME/.config/nvim/init.lua'
alias cr="cursor"

# useful conversions
alias excel_to_csv='libreoffice --headless --convert-to csv'

# tools
# alias copy='xclip -selection clipboard' ## <- FIXME

# work
alias devserver='kitten ssh -t moberg-devserver3 "bash -ic devsrv"'

# python
alias ipy='ipython'

# kitty
alias s='kitten ssh'
alias icat='kitten icat'
alias copy='kitten clipboard'
alias update-kitty='curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin'

# llm calls
alias claude='llm -m claude-3.5-sonnet'
alias pplx='llm -m sonar-large'

### -> CUSTOM FUNCTIONS

#### --> TMUX

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
        echo "Usage: tmuxn <session>"
        return 1
    else
        tmux new-session -s "$1"
    fi
}

function tmuxl() {
    tmux list-sessions
}

#### --> PROGRAM LAUNCHERS

cursor() {
  if [ "$#" -eq 1 ]; then
    (nohup "$USER_BIN/cursor/cursor.AppImage" "$(realpath $1)" &>/dev/null &)
  else
    (nohup "$USER_BIN/cursor/cursor.AppImage" &>/dev/null &)
  fi
}


#### --> COMPILE UTILS

compile() {
  local output_specified=false
  local input_file=""
  local output_file=""
  local args=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o)
        output_specified=true
        output_file="$2"
        args+=("$1" "$2")
        shift 2
        ;;
      *.cpp|*.cxx|*.cc)
        input_file="$1"
        args+=("$1")
        shift
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  # If -o is not specified, generate output filename
  if ! $output_specified && [[ -n "$input_file" ]]; then
    output_file="${input_file%.*}.o"
    args+=("-o" "$output_file")
  fi

  # Call g++ with processed arguments
  g++ \
    -std=c++17 \
    -ggdb \
    -pedantic-errors \
    -Wall -Weffc++ -Wextra -Wconversion -Wsign-conversion \
    "${args[@]}"
}


ktcompile() {
  local run_after=false
  local input_file=""
  local output_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r)
        run_after=true
        shift
        ;;
      *)
        if [ -z "$input_file" ]; then
          input_file="$1"
        elif [ -z "$output_file" ]; then
          output_file="$1"
        else
          echo "Error: Too many arguments."
          echo "Usage: ktcompile [-r] <input_file.kt> [output_file.jar]"
          return 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$input_file" ]; then
    echo "Usage: ktcompile [-r] <input_file.kt> [output_file.jar]"
    return 1
  fi

  if [ -z "$output_file" ]; then
    output_file="${input_file%.kt}.jar"
  fi

  if [ -f "$input_file" ]; then
    kotlinc "$input_file" -include-runtime -d "$output_file"
    if [ $? -eq 0 ] && [ "$run_after" = true ]; then
      java -jar "$output_file"
    fi
  else
    echo "Error: $input_file not found."
  fi
}



#### --> FILE UTILS

loadenv() {
  if [ -f .env ]; then
    source .env
  fi
}

cd() {
  builtin cd $@
  loadenv
}

function mountgdrive() {
    local gdrive_path="$1"
    local local_mount="$2"

    rclone mount "gdrive:$gdrive_path" "$local_mount" \
    --vfs-cache-mode writes \
    --vfs-read-chunk-size 256M \
    --log-level ERROR \
    --fast-list \
    --allow-other \
    --uid 1000
}
