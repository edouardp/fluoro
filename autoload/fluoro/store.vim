" fluoro.vim - persistence for highlights
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

let s:dir = ''

" ---------------------------------------------------------------------------
" Storage location
" ---------------------------------------------------------------------------

function! fluoro#store#dir() abort
  if !empty(s:dir)
    return s:dir
  endif
  let configured = get(g:, 'fluoro_storage_dir', '')
  let dir = empty(configured) ? expand('~/.vim/fluoro') : expand(configured)
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  let s:dir = dir
  return dir
endfunction

" Return the JSON file used for {bufnr}, or an empty String when the buffer
" has no name and therefore cannot be persisted.
function! fluoro#store#file_for(bufnr) abort
  let name = bufname(a:bufnr)
  if empty(name)
    return ''
  endif
  let path = fnamemodify(name, ':p')
  if empty(path)
    return ''
  endif
  let key = exists('*sha256')
        \ ? sha256(path)[0:15]
        \ : substitute(path, '[^A-Za-z0-9]', '_', 'g')[0:100]
  return fluoro#store#dir() . '/' . key . '.json'
endfunction

" ---------------------------------------------------------------------------
" Save / load
" ---------------------------------------------------------------------------

function! fluoro#store#save(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !s:can_persist(bufnr)
    return 0
  endif
  let path = fluoro#store#file_for(bufnr)
  if empty(path)
    return 0
  endif

  let items = fluoro#items(bufnr)
  if empty(items)
    if filereadable(path)
      call delete(path)
    endif
    return 0
  endif

  let highlights = []
  for item in items
    let highlight = {
          \ 'color': item.color,
          \ 'start': [item.start_lnum, item.start_col],
          \ 'end': [item.end_lnum, item.end_col],
          \ }
    if !empty(item.note)
      let highlight.note = item.note
    endif
    call add(highlights, highlight)
  endfor

  let data = {
        \ 'version': 1,
        \ 'file': fnamemodify(bufname(bufnr), ':p'),
        \ 'saved': strftime('%Y-%m-%dT%H:%M:%S'),
        \ 'highlights': highlights,
        \ }

  let temporary = path . '.tmp' . getpid()
  try
    call writefile([json_encode(data)], temporary)
    call rename(temporary, path)
    return len(highlights)
  catch
    call delete(temporary)
    return 0
  endtry
endfunction

function! fluoro#store#load(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !s:can_persist(bufnr)
    return 0
  endif
  let path = fluoro#store#file_for(bufnr)
  if empty(path) || !filereadable(path)
    return 0
  endif

  try
    let data = json_decode(join(readfile(path), "\n"))
  catch
    return 0
  endtry
  if type(data) != v:t_dict || !has_key(data, 'highlights')
    return 0
  endif

  " Start from a clean slate so loading twice cannot duplicate highlights.
  call fluoro#erase_highlights(bufnr)

  let info = getbufinfo(bufnr)
  let last_line = empty(info) ? 1 : get(info[0], 'linecount', 1)

  let loaded = 0
  for highlight in data.highlights
    let color = get(highlight, 'color', '')
    let start = get(highlight, 'start', [])
    let end = get(highlight, 'end', [])
    if empty(color) || len(start) < 2 || len(end) < 2
      continue
    endif
    " Ignore entries that no longer fit the file instead of clamping them
    " onto unrelated text.
    if start[0] < 1 || end[0] < 1 || start[0] > last_line || end[0] > last_line
      continue
    endif
    let id = fluoro#add(start[0], start[1], end[0], end[1], color, bufnr)
    if id > 0
      let note = get(highlight, 'note', '')
      if !empty(note)
        call fluoro#set_note(id, note, bufnr)
      endif
      let loaded += 1
    endif
  endfor
  return loaded
endfunction

function! fluoro#store#save_all() abort
  let saved = 0
  for info in getbufinfo()
    if info.loaded && !empty(info.name)
      let saved += fluoro#store#save(info.bufnr)
    endif
  endfor
  return saved
endfunction

" Delete the stored highlights for a buffer.
function! fluoro#store#forget(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let path = fluoro#store#file_for(bufnr)
  if !empty(path) && filereadable(path)
    call delete(path)
    return 1
  endif
  return 0
endfunction

" Delete all stored highlights.
function! fluoro#store#erase_everything() abort
  let removed = 0
  for path in glob(fluoro#store#dir() . '/*.json', 1, 1)
    if delete(path) == 0
      let removed += 1
    endif
  endfor
  return removed
endfunction

" ---------------------------------------------------------------------------
" Internal
" ---------------------------------------------------------------------------

function! s:can_persist(bufnr) abort
  if !bufexists(a:bufnr) || !bufloaded(a:bufnr)
    return 0
  endif
  if !empty(getbufvar(a:bufnr, '&buftype'))
    return 0
  endif
  if empty(bufname(a:bufnr))
    return 0
  endif
  return 1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sw=2 sts=2 et:
