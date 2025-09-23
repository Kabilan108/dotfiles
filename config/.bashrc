# bashrc

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

# correct spelling errors during tab-completion
shopt -s dirspell 2> /dev/null

# correct spelling errors in args to cd
shopt -s cdspell 2> /dev/null

# this allows you to bookmark locations by setting variables to folder paths
shopt -s cdable_vars


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
export PROMPT_DIRTRIM=2


### -> ENVIRONMENT

if [ -f ~/.bashenv ]; then
    source ~/.bashenv
fi

eval "$(direnv hook bash)"


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

function codex-gpt-5() {
    $HOME/.bun/bin/codex -m gpt-5 -c model_reasoning_effort="${1:-medium}"
}

function fvi() {
    local file=$(fd --hidden --type f --exclude .git \
        | fzf --height 40% --layout=reverse --border \
            --preview "bat --style=numbers --color=always {}") || return
    nvim -- "$file"
}

### -> ALIASES

alias ta="tmuxa"
alias tn="tmuxn"
alias tl="tmuxl"
alias tk="tmuxk"

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
alias copy='xclip -selection clipboard'
alias clipboard='xclip -selection clipboard -o'
alias svi='sudo -E nvim -u $HOME/.config/nvim/init.lua'
alias xlsx2csv='libreoffice --headless --convert-to csv'
