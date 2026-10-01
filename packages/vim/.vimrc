""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Editor Settings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set background=dark

syntax on

" use true colors
set termguicolors

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

" Default mouse on
set mouse=a

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

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins and Plugin Config
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')

" Theme
Plug 'yunlingz/equinusocio-material.vim'

" Language server plugin
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Git diffs in sign column
Plug 'airblade/vim-gitgutter'

" File explorer
Plug 'preservim/nerdtree'

" Fuzzy finder + search
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Status line plugin
Plug 'vim-airline/vim-airline'

" Git integration
Plug 'tpope/vim-fugitive'

" Automatically adjust tabsize based on file
Plug 'tpope/vim-sleuth'

" Collection of language packs
Plug 'sheerun/vim-polyglot'

" Commenting plugin
Plug 'tpope/vim-commentary'

call plug#end()

" Theme (order matters here)
let g:equinusocio_material_bracket_improved = 1
let g:equinusocio_material_style = 'pure'
colorscheme equinusocio_material
let g:airline_theme = 'equinusocio_material'
let g:lightline = {
  \ 'colorscheme': 'equinusocio_material',
  \ }
highlight Normal guibg=NONE ctermbg=NONE
highlight NonText guibg=NONE ctermbg=NONE

" Fugitive git integration
nnoremap <leader>g :Git

" Fuzzy finder
nnoremap <silent> <C-p> :GFiles --cached --exclude-standard --others<CR>

" Search
nnoremap <leader>s :Ag

" Overwrite Ag command to exclude matching filenames
command! -bang -nargs=* Ag call fzf#vim#ag(<q-args>, fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:50%'), <bang>0)

" Airline
let g:airline#extensions#whitespace#enabled = 0

" File tree
let NERDTreeShowHidden = 1
let NERDTreeWinSize = 50

" File tree toggle
function MyNerdToggle()
    if exists("g:NERDTree") && g:NERDTree.IsOpen()
        NERDTreeClose
    elseif @% == "" || &filetype == 'nerdtree'
        NERDTreeToggle
    else
        NERDTreeFind
    endif
endfunction
nnoremap <C-n> :call MyNerdToggle()<CR>

" Linting command
command! -nargs=0 ESLint :CocCommand eslint.executeAutofix

" COC language extensions
let g:coc_global_extensions = [
      \'coc-tsserver',
      \'coc-eslint',
      \'coc-json',
      \'coc-emmet',
      \'coc-yaml',
      \'coc-docker',
      \'coc-prettier',
      \'coc-go']

" Recommended settings for coc
" https://github.com/neoclide/coc.nvim#example-vim-configuration
source ~/.coc.vim

" Note: Stuff below this line has to be after .coc.vim

" Show sign column for git gutter symbols
set signcolumn=yes
hi clear SignColumn

" Format entire file with configured COC formatter
nnoremap <leader>f :Format
