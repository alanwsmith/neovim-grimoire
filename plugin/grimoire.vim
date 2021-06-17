if exists('g:loaded_grimoire') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

hi def link GrimoireSelection Number  
noremap © :Grimoire<CR>
inoremap © <cmd>Grimoire<CR>
" Option g (grimoire)

command! Grimoire lua require'grimoire'.grimoire()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_grimoire = 1


