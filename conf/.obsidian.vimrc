" j, k, I, A work on visual lines
nnoremap j gj
nnoremap k gk
nnoremap I g0i
nnoremap A g$a

" H/L for beginning/end of line
noremap H g0
noremap L g$

" J/K for bigger distance vertical movement
nnoremap J 5gj
nnoremap K 5gk
vnoremap J 5j
vnoremap K 5k

" quickly remove search highlights
nmap <F9> :nohl<CR>

" yank to and paste from system clipboard
set clipboard=unnamed

" map <c-w> + hjkl/vs to obsidian's window/split commands
exmap wq obcommand workspace:close
exmap q obcommand workspace:close

exmap focusRight obcommand editor:focus-right
exmap focusLeft obcommand editor:focus-left
exmap focusTop obcommand editor:focus-top
exmap focusBottom obcommand editor:focus-bottom
exmap splitVertical obcommand workspace:split-vertical
exmap splitHorizontal obcommand workspace:split-horizontal
exmap tabnext obcommand workspace:next-tab
exmap tabprev obcommand workspace:previous-tab

nmap <C-w>l :focusRight<CR>
nmap <C-w>h :focusLeft<CR>
nmap <C-w>k :focusTop<CR>
nmap <C-w>j :focusBottom<CR>
nmap <C-w>v :splitVertical<CR>
nmap <C-w>s :splitHorizontal<CR>
nmap gt :tabnext<CR>
nmap gT :tabprev<CR>

" unmap leader
unmap <Space>

" define ex command aliases for obsidian's core search functions
exmap searchFiles obcommand switcher:open
exmap searchGlobal obcommand global-search:open
exmap searchRecent obcommand switcher:open-recent
exmap searchHelp obcommand app:open-help

" map your neovim keys to the new aliases
noremap <Space>sf :searchFiles<CR>
noremap <Space>b :searchFiles<CR>
noremap <Space>sg :searchGlobal<CR>
noremap <Space>sr :searchRecent<CR>
noremap <Space>sh :searchHelp<CR>
