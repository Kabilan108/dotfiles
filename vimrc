" Set Options
set showmatch                  " Show matching brackets
set mouse=v                    " Middle-click paste with mouse
set number                     " Add line numbers
set wildmode=longest,list      " Get bash-like tab completions
set colorcolumn=90             " Color column (ruler)
set title                      " Show file title
set ruler                      " Show ruler
set visualbell                 " Disable error bell
set background=dark            " Set dark background
set wrap                       " Wrap lines
set backspace=indent,eol,start " Allow backspacing over everything in insert mode
set encoding=UTF-8             " Set encoding

set tabstop=4                  " Set number of columns occupied by a tab
set autoindent                 " Auto-indent new lines
set expandtab                  " Convert tabs to spaces
set shiftwidth=4               " Width for autoindents
set shiftround                 " Round indent to multiple of shiftwidth
set copyindent                 " Copy indent from previous line
set hidden                     " Enable background buffers
set smarttab                   " Use shiftwidth for tabbing
set smartindent                " Enable smartindent

set ignorecase                 " Case insensitive matching
set hlsearch                   " Highlight search results
set incsearch                  " Incremental search
set wrapscan                   " Searches wrap around end of file

set splitbelow                 " Open new windows below current
set splitright                 " Open new windows right of current

" Set termguicolors to enable highlight groups
set termguicolors

" Directory to store backup files
set backupdir=/home/muaddib/.cache/nvim

" Define whitespace characters
set listchars=eol:↲,tab:> ,space:·,trail:·

" Map keybindings
nnoremap <silent> ,<space> :nohlsearch<CR>      " Clear search highlights
nnoremap <silent> <C-A-S> :set invspell<CR>     " Toggle spellcheck
nnoremap <silent> <F2> :set invnumber<CR>       " Toggle line numbers
nnoremap <silent> <F4> :set list! list?<CR>     " Toggle whitespace characters

" Keybindings for split navigation
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k
nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-l> <C-w>l