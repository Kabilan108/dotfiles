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


### -> PROMPT

# export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]: \[\033[01;34m\]\w\[\033[00m\] \$ "
# export PS1="\t \[\033[32m\]\w\[\033[33m\]\$(GIT_PS1_SHOWUNTRACKEDFILES=1 GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1)\[\033[00m\]\n> "
# export PS1="\[\033[32m\]\w\[\033[33m\]\$(GIT_PS1_SHOWUNTRACKEDFILES=1 GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1)\[\033[00m\]\n> "
__bash_prompt() {
    local userpart='`export XIT=$? \
        && echo -n "\[\033[0;32m\]\u " \
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


### -> ALIASES

alias nohist='HISTFILE-/dev/null'

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

# editors
alias vi='nvim'
alias svi='sudo -E nvim'
alias cr="cursor"

# tools
alias copy='xclip -selection clipboard' ## <- FIXME

# python
alias ipy='ipython'

# kitty
alias s='kitten ssh'
alias icat='kitten icat'

# llm calls
alias claude='llm -m claude-3.5-sonnet'

### -> CUSTOM FUNCTIONS

#### --> TMUX

# function tmuxa() {
#     if [[ -z "$1" ]]; then
#         echo "Usage: tmuxa <session>"
#         return 1
#     else
#         tmux attach-session -t "$1"
#     fi
# }
#
# function tmuxn() {
#     if [[ -z "$1" ]]; then
#         echo "Usage: tmuxn <session>"
#         return 1
#     else
#         tmux new-session -s "$1"
#     fi
# }
#
# function tmuxl() {
#     tmux list-sessions
# }

#### --> PROGRAM LAUNCHERS

cursor() {
  if [ "$#" -eq 1 ]; then
    (nohup "$USER_BIN/cursor/cursor.AppImage" "$(realpath $1)" &>/dev/null &)
  else
    echo "Usage: cursor <argument>"
  fi
}


#### --> C++ UTILS

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

# function mount_gdrive() {
#   rclone mount gdrive:Drexel/Academic/05\ -\ Senior/01\ -\ Fall\ Quarter/ ~/Class \
#     --vfs-cache-mode writes \
#     --vfs-read-chunk-size 256M \
#     --log-level ERROR \
#     --fast-list \
#     --allow-other \
#     --uid 1000
# }

cp_() {
  # wrapper for rclone -> copy with progress bar

  local OPTIND
  local recursive=false
  local verbose=false
  local preserve=false

  # Parse options
  while getopts "rvp" opt; do
    case $opt in
      r) recursive=true ;;
      v) verbose=true ;;
      p) preserve=true ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND-1))

  # Check for correct number of arguments
  if [ $# -lt 2 ]; then
    echo "Usage: cp_ [-rvp] source... destination" >&2
    return 1
  fi

  # Prepare rsync options
  local rsync_opts="-a --progress"
  $recursive || rsync_opts+=" --no-recursive"
  $verbose && rsync_opts+=" -v"
  $preserve || rsync_opts+=" --no-perms --no-owner --no-group"

  # Prepare source and destination
  local sources=("${@:1:$#-1}")
  local dest="${!#}"

  # Check if destination is a directory
  if [ -d "$dest" ]; then
    # If copying multiple sources or recursive, destination must be a directory
    if [ ${#sources[@]} -gt 1 ] || $recursive; then
        :  # Destination is already a directory, do nothing
    else
        # If single file to single file, remove trailing slash
        dest="${dest%/}"
    fi
  elif [ ${#sources[@]} -gt 1 ]; then
    echo "cp_with_progress: target '$dest' is not a directory" >&2
    return 1
  fi

  # Perform the copy operation
  if $verbose; then
    rsync $rsync_opts "${sources[@]}" "$dest"
  else
    rsync $rsync_opts "${sources[@]}" "$dest" | pv -l -s "$(rsync --no-h --no-i -r --stats "${sources[@]}" "$dest" 2>&1 | awk '/Total file size:/ {print $4}')" > /dev/null
  fi

  local status=$?
  if [ $status -eq 0 ]; then
    echo "Copy completed successfully."
  else
    echo "Error occurred during copy. Exit status: $status" >&2
  fi

  return $status
}


. "$HOME/.cargo/env"
