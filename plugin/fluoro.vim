" fluoro.vim - fluorescent highlights that stick to your text
" Maintainer: Edouard Poor
" License: MIT

if exists('g:loaded_fluoro')
  finish
endif
if !has('textprop')
  finish
endif
let g:loaded_fluoro = 1

let s:save_cpo = &cpo
set cpo&vim

" ---------------------------------------------------------------------------
" Options
" ---------------------------------------------------------------------------

let s:options = {
      \ 'fluoro_default_mappings': 1,
      \ 'fluoro_autosave': 1,
      \ 'fluoro_autoload': 1,
      \ 'fluoro_note_cursor': 1,
      \ 'fluoro_note_mouse': 1,
      \ }
for [s:name, s:default] in items(s:options)
  if !exists('g:' . s:name)
    execute 'let g:' . s:name . ' = ' . string(s:default)
  endif
endfor
unlet s:name s:default s:options

" ---------------------------------------------------------------------------
" Commands
" ---------------------------------------------------------------------------

command! -range -nargs=? -complete=customlist,fluoro#complete
      \ FluoroHighlight
      \ call fluoro#cmd_highlight(<range>, <line1>, <line2>, <q-args>)

command! -range -nargs=0 FluoroErase
      \ call fluoro#cmd_erase(<range>, <line1>, <line2>)

command! -nargs=0 FluoroEraseBuffer call fluoro#erase_buffer()
command! -nargs=0 FluoroEraseEverything call fluoro#erase_everything()
command! -nargs=0 FluoroList        call fluoro#list()
command! -nargs=0 FluoroInfo        call fluoro#info()
command! -nargs=? FluoroNext        call fluoro#next(empty(<q-args>) ? 1 : str2nr(<q-args>))
command! -nargs=? FluoroPrev        call fluoro#prev(empty(<q-args>) ? 1 : str2nr(<q-args>))
command! -nargs=0 FluoroCycle       call fluoro#cycle_color()
command! -nargs=? -complete=customlist,fluoro#complete FluoroColor
      \ call fluoro#cmd_color(<q-args>)
command! -nargs=0 FluoroSave        call fluoro#save()
command! -nargs=0 FluoroLoad        call fluoro#load()

command! -nargs=? FluoroNote        call fluoro#cmd_note(<q-args>)
command! -nargs=0 FluoroNoteClear   call fluoro#cmd_note_clear()
command! -nargs=0 FluoroNoteShow    call fluoro#note_cursor()

" Convenience aliases.
command! -range -nargs=? -complete=customlist,fluoro#complete Fluoro
      \ call fluoro#cmd_highlight(<range>, <line1>, <line2>, <q-args>)

" ---------------------------------------------------------------------------
" <Plug> mappings
" ---------------------------------------------------------------------------

nnoremap <silent> <Plug>(fluoro-highlight) :<C-u>call fluoro#cmd_highlight(0, line('.'), line('.'), '')<CR>
nnoremap <silent> <Plug>(fluoro-erase)     :<C-u>call fluoro#erase_cursor()<CR>
nnoremap <silent> <Plug>(fluoro-cycle)     :<C-u>call fluoro#cycle_or_toggle()<CR>
nnoremap <silent> <Plug>(fluoro-next)      :<C-u>call fluoro#next(v:count1)<CR>
nnoremap <silent> <Plug>(fluoro-prev)      :<C-u>call fluoro#prev(v:count1)<CR>
nnoremap <silent> <Plug>(fluoro-info)      :<C-u>call fluoro#info()<CR>
nnoremap <silent> <Plug>(fluoro-note)       :<C-u>call fluoro#cmd_note('')<CR>
nnoremap <silent> <Plug>(fluoro-note-clear) :<C-u>call fluoro#cmd_note_clear()<CR>
nnoremap <silent> <Plug>(fluoro-note-show)  :<C-u>call fluoro#note_cursor()<CR>
nnoremap <silent> <Plug>(fluoro-note-click) :<C-u>call fluoro#note_cursor()<CR>

xnoremap <silent> <Plug>(fluoro-highlight) :<C-u>call fluoro#highlight_visual('')<CR>
xnoremap <silent> <Plug>(fluoro-highlight-first) :<C-u>call fluoro#highlight_visual(fluoro#first_color())<CR>
xnoremap <silent> <Plug>(fluoro-erase)     :<C-u>call fluoro#erase_visual()<CR>

" One <Plug> mapping per color, e.g. <Plug>(fluoro-highlight-yellow).
for s:color in fluoro#colors()
  let s:key = substitute(s:color, '[^A-Za-z0-9_-]', '_', 'g')
  execute 'xnoremap <silent> <Plug>(fluoro-highlight-' . s:key . ')'
        \ . ' :<C-u>call fluoro#highlight_visual(' . string(s:color) . ')<CR>'
endfor
unlet s:color s:key

" ---------------------------------------------------------------------------
" Default mappings
" ---------------------------------------------------------------------------

if g:fluoro_default_mappings
  if empty(maparg(',,', 'n'))
    nmap ,, <Plug>(fluoro-cycle)
  endif
  if empty(maparg(',,', 'x'))
    xmap ,, <Plug>(fluoro-highlight-first)
  endif
  if empty(maparg(',n', 'n'))
    nmap ,n <Plug>(fluoro-note)
  endif
  if empty(maparg(',N', 'n'))
    nmap ,N <Plug>(fluoro-note-clear)
  endif
  if empty(maparg(']f', 'n'))
    nmap ]f <Plug>(fluoro-next)
  endif
  if empty(maparg('[f', 'n'))
    nmap [f <Plug>(fluoro-prev)
  endif
  if empty(maparg('gF', 'x'))
    xmap gF <Plug>(fluoro-highlight-first)
  endif
  " Clicking a highlight shows its note immediately.  The RHS repeats the
  " click first so cursor positioning is unchanged.
  if g:fluoro_note_mouse && has('mouse') && empty(maparg('<LeftMouse>', 'n'))
    nnoremap <silent> <LeftMouse>
          \ <LeftMouse><Plug>(fluoro-note-click)
  endif
endif

" ---------------------------------------------------------------------------
" Autocommands
" ---------------------------------------------------------------------------

augroup fluoro
  autocmd!
  autocmd ColorScheme * call fluoro#apply_highlights()
  if g:fluoro_note_cursor
    autocmd CursorMoved * call fluoro#note_cursor_leave()
    autocmd CursorHold * call fluoro#note_cursor()
  endif
  autocmd BufLeave,WinLeave * call fluoro#note_hide()
  autocmd InsertEnter * call fluoro#note_hide()
  autocmd VimResized * call fluoro#note_hide()
  if exists('##WinScrolled')
    autocmd WinScrolled * call fluoro#note_hide()
  endif
  if g:fluoro_autoload
    autocmd BufReadPost * call fluoro#store#load(str2nr(expand('<abuf>')))
  endif
  if g:fluoro_autosave
    autocmd BufWritePost * call fluoro#store#save(str2nr(expand('<abuf>')))
    autocmd BufUnload    * call fluoro#store#save(str2nr(expand('<abuf>')))
    autocmd VimLeavePre  * call fluoro#store#save_all()
  endif
augroup END

" The GUI can tell us when the mouse moves over a highlight.  Terminal Vim has
" no mouse-move events, so there the cursor is used instead.
if g:fluoro_note_mouse && has('gui_running') && exists('+mousemoveevent')
  set mousemoveevent
  if empty(maparg('<MouseMove>', 'n'))
    nnoremap <silent> <MouseMove> :<C-u>call fluoro#note_hover()<CR>
  endif
endif

" Defining the palette and property types up front means highlights are visible
" as soon as a buffer is read.
call fluoro#init()

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sw=2 sts=2 et:
