""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Editor Settings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set background=dark

syntax on

" use true colors
"set termguicolors

" Line numbers
set number
set relativenumber

" Use a fast tty connection
set ttyfast

" Highlight + incremental search
set hlsearch
set incsearch

" Cursor
set cursorline
set scrolloff=20

" Set default tab size to 2
set tabstop=2

" Replace tabs with spaces
set expandtab

" Dont create swap files for changed files
set noswapfile

" Dont wrap lines
set nowrap

" Use hjkl to move between vim panes
noremap <C-h> <C-w>h
noremap <C-j> <C-w>j
noremap <C-k> <C-w>k
noremap <C-l> <C-w>l

" Toggle mouse mode to enable click and scroll
function ToggleMouse()
  if &mouse == ""
    set mouse=a
  else
    set mouse=""
  endif
endfunction
nnoremap mm :call ToggleMouse()<CR>

" Make Y behave like D and C
nnoremap Y y$

" Keep cursor centered when searching, scrolling, using J etc
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap J mzJ`z

" Undo break points (',', '.', '!', '?') not the whole thing just typed
" <c-g> breaks the undo sequence and starts a new change
inoremap , ,<c-g>u
inoremap . .<c-g>u
inoremap ! !<c-g>u
inoremap ? ?<c-g>u

" Moving text with all modes (visual, insert, normal)
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv
inoremap <C-k> <esc>:m .-2<CR>==
inoremap <C-j> <esc>:m .+1<CR>==
nnoremap <leader>j :m .+2<CR>==
nnoremap <leader>k :m .-2<CR>==

" Show sign column for git gutter symbols
set signcolumn=yes
hi clear SignColumn

" Format entire file with configured COC formatter
nnoremap <leader>f :Format
