" fluoro.vim - fluorescent highlights that stick to your text
" Maintainer: Edouard Poor
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

" ---------------------------------------------------------------------------
" Defaults
" ---------------------------------------------------------------------------

" Every palette entry is either:
"   - a highlight group name (String), or
"   - a Dictionary of highlight attributes.
let s:default_palette = {
      \ 'yellow': {'guibg': '#f6f65a', 'guifg': '#101010', 'ctermbg': '227', 'ctermfg': '16'},
      \ 'green':  {'guibg': '#82f58c', 'guifg': '#101010', 'ctermbg': '120', 'ctermfg': '16'},
      \ 'blue':   {'guibg': '#8fb3ff', 'guifg': '#101010', 'ctermbg': '111', 'ctermfg': '16'},
      \ 'pink':   {'guibg': '#ff9ecb', 'guifg': '#101010', 'ctermbg': '212', 'ctermfg': '16'},
      \ }

" The classic fluoro pen colors, in the order ',, ' cycles through them.
let s:default_order = ['yellow', 'green', 'blue', 'pink']

let s:palette       = {}
let s:type_by_color = {}
let s:color_by_type = {}
let s:current_color = ''
let s:next_id       = 1000000
let s:active_note   = {}
let s:group_by_color = {}

" ---------------------------------------------------------------------------
" Setup
" ---------------------------------------------------------------------------

function! fluoro#init() abort
  if exists('s:initialized')
    return
  endif
  let s:initialized = 1

  let s:palette = copy(s:default_palette)
  let user_palette = get(g:, 'fluoro_palette', {})
  if type(user_palette) == v:t_dict
    call extend(s:palette, user_palette, 'force')
  endif

  for s:color in keys(s:palette)
    call s:define_color(s:color)
  endfor
  unlet s:color

  call s:define_note_hl()
  if empty(prop_type_get('fluoro_note'))
    call prop_type_add('fluoro_note', {
          \ 'highlight': 'FluoroNote',
          \ 'combine': 0,
          \ 'priority': 10000,
          \ })
  endif

  " Avoid collisions with text properties left over from a previous load.
  let s:next_id = localtime()

  let configured = get(g:, 'fluoro_current_color', '')
  if !empty(configured)
    let s:current_color = s:resolve_color(configured, 1)
  endif
  if empty(s:current_color)
    let s:current_color = s:first_color()
  endif
endfunction

" Re-define our highlight groups, e.g. after ':colorscheme' has cleared them.
function! fluoro#apply_highlights() abort
  if !exists('s:initialized')
    return
  endif
  for [s:color, s:spec] in items(s:palette)
    if type(s:spec) == v:t_dict
      call s:define_hl('Fluoro' . s:capitalize(s:color), s:spec)
    endif
  endfor
  unlet s:color s:spec
  call s:define_note_hl()
endfunction

" ---------------------------------------------------------------------------
" Colors
" ---------------------------------------------------------------------------

function! fluoro#colors() abort
  call fluoro#init()
  let colors = []
  for color in s:default_order
    if has_key(s:palette, color)
      call add(colors, color)
    endif
  endfor
  for color in sort(keys(s:palette))
    if index(colors, color) < 0
      call add(colors, color)
    endif
  endfor
  return colors
endfunction

function! fluoro#complete(arglead, cmdline, cursorpos) abort
  let candidates = fluoro#colors() + keys(s:type_by_color)
  let matches = []
  for candidate in candidates
    if stridx(candidate, a:arglead) == 0 && index(matches, candidate) < 0
      call add(matches, candidate)
    endif
  endfor
  return sort(matches)
endfunction

" Resolve a color name.  With {strict} unset, unknown names are accepted and
" become ad-hoc colors backed by a highlight group of the same name.
function! s:resolve_color(name, ...) abort
  call fluoro#init()
  let strict = a:0 ? a:1 : 1
  let name = a:name
  if empty(name)
    return ''
  endif
  if has_key(s:palette, name)
    call s:define_color(name)
    return name
  endif
  if hlexists(name)
    call s:define_color(name)
    return name
  endif
  if !strict
    call s:define_color(name)
    return name
  endif
  return ''
endfunction

" The first color of the cycle, i.e. classic yellow unless overridden.
function! fluoro#first_color() abort
  call fluoro#init()
  return s:first_color()
endfunction

" Public wrapper; see s:resolve_color().
function! fluoro#resolve_color(name, ...) abort
  return s:resolve_color(a:name, a:0 ? a:1 : 1)
endfunction

function! fluoro#current_color(...) abort
  call fluoro#init()
  if a:0 && !empty(a:1)
    let color = s:resolve_color(a:1, 1)
    if empty(color)
      call s:error('unknown color "' . a:1 . '"')
      return s:current_color
    endif
    let s:current_color = color
    let g:fluoro_current_color = color
  endif
  return s:current_color
endfunction

function! fluoro#cycle_pen() abort
  call fluoro#init()
  let colors = fluoro#colors()
  if empty(colors)
    return s:current_color
  endif
  let index = index(colors, s:current_color)
  let s:current_color = colors[(index + 1) % len(colors)]
  let g:fluoro_current_color = s:current_color
  return s:current_color
endfunction

function! fluoro#cmd_color(arg) abort
  if empty(a:arg)
    let color = fluoro#cycle_pen()
  else
    let color = fluoro#current_color(a:arg)
  endif
  echo 'fluoro: pen is ' . color
endfunction

" ---------------------------------------------------------------------------
" Querying highlights
" ---------------------------------------------------------------------------

" Return a sorted List of all highlights in {bufnr} (default: current buffer).
" Each item has the keys:
"   id, color, start_lnum, start_col, end_lnum, end_col
function! fluoro#items(...) abort
  call fluoro#init()
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !bufexists(bufnr) || !bufloaded(bufnr)
    return []
  endif
  let types = values(s:type_by_color)
  if empty(types)
    return []
  endif

  let props = prop_list(1, {'end_lnum': -1, 'types': types, 'bufnr': bufnr})
  let notes = s:get_notes(bufnr)
  let items = []
  let index = {}
  for prop in props
    let id = get(prop, 'id', 0)
    if id <= 0
      continue
    endif
    if !has_key(index, id)
      let index[id] = len(items)
      call add(items, {
            \ 'id': id,
            \ 'color': get(s:color_by_type, get(prop, 'type', ''), ''),
            \ 'start_lnum': get(prop, 'lnum', 1),
            \ 'start_col': get(prop, 'col', 1),
            \ 'end_lnum': get(prop, 'lnum', 1),
            \ 'end_col': get(prop, 'col', 1),
            \ 'start': 0,
            \ 'end': 0,
            \ 'note': get(notes, id, ''),
            \ })
    endif
    let item = items[index[id]]
    if get(prop, 'start', 0)
      let item.start_lnum = prop.lnum
      let item.start_col = prop.col
      let item.start = 1
    endif
    if get(prop, 'end', 0)
      let item.end_lnum = prop.lnum
      let item.end_col = prop.col + get(prop, 'length', 0)
      let item.end = 1
    endif
  endfor

  call filter(items, 'v:val.start && v:val.end && !empty(v:val.color)')
  call sort(items, function('s:compare_items'))
  return items
endfunction

function! fluoro#count(...) abort
  return len(fluoro#items(a:0 ? a:1 : bufnr('%')))
endfunction

function! fluoro#status() abort
  let total = fluoro#count()
  return total ? 'F' . total : ''
endfunction

" ---------------------------------------------------------------------------
" Adding / removing
" ---------------------------------------------------------------------------

" Add a highlight.  Returns the new property id, or 0 on failure.
function! fluoro#add(sl, sc, el, ec, color, ...) abort
  call fluoro#init()
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !bufexists(bufnr) || !bufloaded(bufnr)
    return 0
  endif
  let color = s:resolve_color(a:color, 1)
  if empty(color)
    return 0
  endif
  let type = s:define_color(color)
  let [sl, sc, el, ec] = s:normalize_range(a:sl, a:sc, a:el, a:ec, bufnr)
  let id = s:new_id()
  call prop_add(sl, sc, {
        \ 'type': type,
        \ 'id': id,
        \ 'end_lnum': el,
        \ 'end_col': ec,
        \ 'bufnr': bufnr,
        \ })
  return id
endfunction

" Add the highlight on the same range, or remove it.  If the same range
" already has a different color, recolor it instead.
function! fluoro#toggle_range(sl, sc, el, ec, color, ...) abort
  call fluoro#init()
  let bufnr = a:0 ? a:1 : bufnr('%')
  let color = s:resolve_color(a:color, 1)
  if empty(color)
    return -1
  endif
  let [sl, sc, el, ec] = s:normalize_range(a:sl, a:sc, a:el, a:ec, bufnr)

  let existing = []
  for item in fluoro#items(bufnr)
    if item.start_lnum == sl && item.start_col == sc
          \ && item.end_lnum == el && item.end_col == ec
      call add(existing, item)
    endif
  endfor

  if !empty(existing) && existing[0].color == color
    for item in existing
      call s:remove_id(item.id, bufnr)
    endfor
    return -1
  endif

  let note = empty(existing) ? '' : existing[0].note
  for item in existing
    call s:remove_id(item.id, bufnr)
  endfor
  let id = fluoro#add(sl, sc, el, ec, color, bufnr)
  if id > 0 && !empty(note)
    call fluoro#set_note(id, note, bufnr)
  endif
  return id
endfunction

function! fluoro#remove(id, ...) abort
  return s:remove_id(a:id, a:0 ? a:1 : bufnr('%'))
endfunction

" Remove the highlight(s) under the cursor.
function! fluoro#erase_cursor() abort
  call fluoro#init()
  let items = []
  for item in fluoro#items()
    if s:covers(item, line('.'), col('.'))
      call add(items, item)
    endif
  endfor
  if empty(items)
    echo 'fluoro: no highlight under the cursor'
    return 0
  endif
  for item in items
    call s:remove_id(item.id)
  endfor
  echo printf('fluoro: removed %d highlight(s)', len(items))
  return len(items)
endfunction

" Remove all highlights that intersect the given range.
function! fluoro#erase_range(sl, sc, el, ec, ...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let [sl, sc, el, ec] = s:normalize_range(a:sl, a:sc, a:el, a:ec, bufnr)
  let removed = 0
  for item in fluoro#items(bufnr)
    if s:overlaps(item, sl, sc, el, ec)
      call s:remove_id(item.id, bufnr)
      let removed += 1
    endif
  endfor
  return removed
endfunction

function! fluoro#erase_visual() abort
  let range = s:visual_range()
  if empty(range)
    echo 'fluoro: no visual selection'
    return 0
  endif
  let removed = call('fluoro#erase_range', range)
  echo printf('fluoro: removed %d highlight(s)', removed)
  return removed
endfunction

" Remove every highlight from {bufnr} (default: current buffer).
function! fluoro#erase_highlights(...) abort
  call fluoro#init()
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !bufexists(bufnr) || !bufloaded(bufnr)
    return 0
  endif
  let types = values(s:type_by_color)
  if empty(types)
    return 0
  endif
  call s:set_notes(bufnr, {})
  if !empty(s:active_note) && s:active_note.bufnr == bufnr
    call s:hide_note()
  endif
  return prop_remove({'types': types, 'all': 1, 'bufnr': bufnr})
endfunction

function! fluoro#erase_buffer() abort
  let total = fluoro#erase_highlights()
  call fluoro#store#forget(bufnr('%'))
  echo printf('fluoro: erased %d highlight(s)', total)
  return total
endfunction

function! fluoro#erase_everything() abort
  let total = 0
  for info in getbufinfo()
    if info.loaded
      let total += fluoro#erase_highlights(info.bufnr)
    endif
  endfor
  call fluoro#store#erase_everything()
  echo printf('fluoro: erased %d highlight(s) from all buffers', total)
  return total
endfunction

" Cycle the color of the highlight under the cursor.
function! fluoro#cycle_color() abort
  let item = s:item_at_cursor()
  if empty(item)
    echo 'fluoro: no highlight under the cursor'
    return ''
  endif
  let colors = fluoro#colors()
  let index = index(colors, item.color)
  let color = colors[(index + 1) % len(colors)]
  let id = item.id
  let note = item.note
  let range = [item.start_lnum, item.start_col, item.end_lnum, item.end_col]
  call s:remove_id(id)
  let new_id = call('fluoro#add', range + [color])
  if new_id > 0 && !empty(note)
    call fluoro#set_note(new_id, note)
  endif
  echo 'fluoro: ' . color
  return color
endfunction

" Normal-mode `,,`: highlight the word under the cursor.  On an existing
" highlight, advance to the next color and remove it after the last color.
function! fluoro#cycle_or_toggle() abort
  call fluoro#init()
  let item = s:item_at_cursor()
  if empty(item)
    let color = s:first_color()
    let range = s:word_range()
    let id = call('fluoro#add', range + [color])
    if id > 0
      let s:current_color = color
      let g:fluoro_current_color = color
      echo 'fluoro: ' . color
    endif
    return color
  endif

  let colors = fluoro#colors()
  let index = index(colors, item.color)
  let note = item.note
  let range = [item.start_lnum, item.start_col, item.end_lnum, item.end_col]
  call s:remove_id(item.id)

  if index < 0
    let color = colors[0]
  elseif index + 1 >= len(colors)
    echo 'fluoro: off'
    return ''
  else
    let color = colors[index + 1]
  endif

  let new_id = call('fluoro#add', range + [color])
  if new_id > 0 && !empty(note)
    call fluoro#set_note(new_id, note)
  endif
  let s:current_color = color
  let g:fluoro_current_color = color
  echo 'fluoro: ' . color
  return color
endfunction

" ---------------------------------------------------------------------------
" Notes
" ---------------------------------------------------------------------------

" Attach {text} to the highlight with {id}.  An empty {text} removes the note.
function! fluoro#set_note(id, text, ...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let text = s:clean_note(a:text)
  let notes = s:get_notes(bufnr)
  if empty(text)
    if has_key(notes, a:id)
      call remove(notes, a:id)
    endif
  else
    let notes[a:id] = text
  endif
  call s:set_notes(bufnr, notes)

  " Refresh the displayed note when this highlight is the active one.
  if !empty(s:active_note) && s:active_note.bufnr == bufnr && s:active_note.id == a:id
    if empty(text)
      call s:hide_note()
    else
      let item = s:item_for_id(bufnr, a:id)
      if !empty(item)
        call s:show_note(item, bufnr)
      endif
    endif
  endif
  return text
endfunction

function! fluoro#get_note(id, ...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  return get(s:get_notes(bufnr), a:id, '')
endfunction

" :FluoroNote [{text}] - set a note on the highlight under the cursor.
" Without {text}, ask for it interactively, prefilled with the current note.
function! fluoro#cmd_note(arg) abort
  let item = s:item_at_cursor()
  if empty(item)
    call s:error('no highlight under the cursor')
    return ''
  endif

  let text = a:arg
  if empty(text)
    call inputsave()
    try
      let text = input('Note: ', item.note)
    finally
      call inputrestore()
    endtry
  endif

  call fluoro#set_note(item.id, text)
  if empty(s:clean_note(text))
    echo 'fluoro: note removed'
  else
    let item.note = s:clean_note(text)
    call s:show_note(item, bufnr('%'))
    echo 'fluoro: note set'
  endif
  return item.note
endfunction

function! fluoro#cmd_note_clear() abort
  let item = s:item_at_cursor()
  if empty(item)
    call s:error('no highlight under the cursor')
    return
  endif
  call fluoro#set_note(item.id, '')
  echo 'fluoro: note removed'
endfunction

" Cheap check used on CursorMoved: hide a visible note only when the cursor
" has left it.  Showing is left to CursorHold to keep movement snappy.
function! fluoro#note_cursor_leave() abort
  if empty(s:active_note)
    return
  endif
  let item = s:item_at_cursor()
  if empty(item) || item.id != s:active_note.id || s:active_note.bufnr != bufnr('%')
    call s:hide_note()
  endif
endfunction

" Show the note for the highlight under the cursor, or hide the current note.
function! fluoro#note_cursor() abort
  let item = s:item_at_cursor()
  if empty(item) || empty(item.note)
    call s:hide_note()
    return
  endif
  call s:show_note(item, bufnr('%'))
endfunction

" Show the note for the highlight under the mouse pointer.  <MouseMove> is
" only delivered by the GUI; in a terminal use fluoro#note_cursor().
function! fluoro#note_hover() abort
  if !exists('*getmousepos') || !exists('*getwininfo')
    return
  endif
  let mouse = getmousepos()
  let winid = get(mouse, 'winid', 0)
  if winid > 0 && !empty(s:active_note) && get(s:active_note, 'popup', 0) == winid
    return
  endif
  let lnum = get(mouse, 'line', 0)
  let col = get(mouse, 'column', 0)
  if winid <= 0 || lnum <= 0 || col <= 0
    call s:hide_note()
    return
  endif
  let info = getwininfo(winid)
  if empty(info)
    call s:hide_note()
    return
  endif
  let bufnr = info[0].bufnr
  let item = s:item_at(bufnr, lnum, col)
  if empty(item) || empty(item.note)
    call s:hide_note()
    return
  endif
  call s:show_note(item, bufnr)
endfunction

function! fluoro#note_hide() abort
  call s:hide_note()
endfunction

" ---------------------------------------------------------------------------
" Navigation
" ---------------------------------------------------------------------------

function! fluoro#next(...) abort
  let steps = a:0 ? max([1, a:1]) : 1
  return s:jump(steps, 1)
endfunction

function! fluoro#prev(...) abort
  let steps = a:0 ? max([1, a:1]) : 1
  return s:jump(steps, -1)
endfunction

function! s:jump(count, direction) abort
  let items = fluoro#items()
  if empty(items)
    echo 'fluoro: no highlights'
    return {}
  endif

  let pos = [line('.'), col('.')]
  " When moving backwards, a cursor inside a highlight counts as being on that
  " highlight, so go to the highlight before it rather than to its start.
  if a:direction < 0
    let current = s:item_at_cursor()
    if !empty(current)
      let pos = [current.start_lnum, current.start_col]
    endif
  endif
  let target = {}
  for _ in range(a:count)
    let found = {}
    if a:direction > 0
      for item in items
        if s:pos_cmp([item.start_lnum, item.start_col], pos) > 0
          let found = item
          break
        endif
      endfor
      if empty(found)
        if get(g:, 'fluoro_wrap', 1)
          let found = items[0]
        else
          echo 'fluoro: last highlight'
          return target
        endif
      endif
    else
      for item in reverse(copy(items))
        if s:pos_cmp([item.start_lnum, item.start_col], pos) < 0
          let found = item
          break
        endif
      endfor
      if empty(found)
        if get(g:, 'fluoro_wrap', 1)
          let found = items[-1]
        else
          echo 'fluoro: first highlight'
          return target
        endif
      endif
    endif
    let target = found
    let pos = [found.start_lnum, found.start_col]
  endfor

  if !empty(target)
    let line_length = strlen(getline(target.start_lnum))
    call cursor(target.start_lnum, max([1, min([target.start_col, max([1, line_length])])]))
  endif
  return target
endfunction

" ---------------------------------------------------------------------------
" Listing / inspection
" ---------------------------------------------------------------------------

function! fluoro#list() abort
  let items = fluoro#items()
  if empty(items)
    echo 'fluoro: no highlights in this buffer'
    return
  endif
  let filename = empty(bufname('%')) ? '' : expand('%:p')
  let qf = []
  for item in items
    let last = min([item.end_lnum, item.start_lnum])
    let snippet = join(getline(item.start_lnum, last), ' ')
    let snippet = substitute(snippet, '\s\+', ' ', 'g')
    if strchars(snippet) > 80
      let snippet = strcharpart(snippet, 0, 77) . '...'
    endif
    let text = printf('[%s] %s', item.color, snippet)
    if !empty(item.note)
      let text .= '  -- ' . item.note
    endif
    call add(qf, {
          \ 'filename': filename,
          \ 'lnum': item.start_lnum,
          \ 'col': item.start_col,
          \ 'text': text,
          \ 'type': 'I',
          \ })
  endfor
  call setqflist([], 'r', {'title': 'Fluoro highlights', 'items': qf})
  botright cwindow
endfunction

function! fluoro#info() abort
  let all = fluoro#items()
  let here = filter(copy(all), 's:covers(v:val, line("."), col("."))')
  if empty(here)
    echo printf('fluoro: no highlight here; %d in buffer; pen is %s',
          \ len(all), fluoro#current_color())
    return {}
  endif
  let parts = []
  for item in here
    call add(parts, printf('%s %d:%d-%d:%d', item.color,
          \ item.start_lnum, item.start_col, item.end_lnum, item.end_col))
  endfor
  echo 'fluoro: ' . join(parts, ', ')
  return here
endfunction

" ---------------------------------------------------------------------------
" Commands' implementation
" ---------------------------------------------------------------------------

function! fluoro#cmd_highlight(range, l1, l2, arg) abort
  call fluoro#init()
  let arg = substitute(a:arg, '^\s*\(.\{-}\)\s*$', '\1', '')
  let color = s:current_color
  if !empty(arg)
    let color = s:resolve_color(arg, 1)
    if empty(color)
      call s:error('unknown color "' . arg . '"')
      return
    endif
    let s:current_color = color
  endif

  if a:range == 0
    let range = s:word_range()
  elseif a:range == 2
    let range = s:marks_range(a:l1, a:l2)
    if empty(range)
      let range = [a:l1, 1, a:l2, s:byte_len(bufnr('%'), a:l2) + 1]
    endif
  else
    let range = [a:l1, 1, a:l2, s:byte_len(bufnr('%'), a:l2) + 1]
  endif

  call call('fluoro#toggle_range', range + [color])
  return range
endfunction

function! fluoro#highlight_visual(...) abort
  let color = a:0 && !empty(a:1) ? a:1 : s:current_color
  let range = s:visual_range()
  if empty(range)
    echo 'fluoro: no visual selection'
    return
  endif
  call call('fluoro#toggle_range', range + [color])
  return range
endfunction

function! fluoro#cmd_erase(range, l1, l2) abort
  if a:range == 0
    return fluoro#erase_cursor()
  endif
  if a:range == 2
    let range = s:marks_range(a:l1, a:l2)
  else
    let range = []
  endif
  if empty(range)
    let range = [a:l1, 1, a:l2, s:byte_len(bufnr('%'), a:l2) + 1]
  endif
  let removed = call('fluoro#erase_range', range)
  echo printf('fluoro: removed %d highlight(s)', removed)
  return removed
endfunction

" ---------------------------------------------------------------------------
" Persistence wrappers
" ---------------------------------------------------------------------------

function! fluoro#save(...) abort
  return call('fluoro#store#save', a:000)
endfunction

function! fluoro#load(...) abort
  return call('fluoro#store#load', a:000)
endfunction

" ---------------------------------------------------------------------------
" Internal helpers
" ---------------------------------------------------------------------------

function! s:first_color() abort
  let colors = fluoro#colors()
  return empty(colors) ? 'yellow' : colors[0]
endfunction

function! s:capitalize(name) abort
  return substitute(a:name, '^.', '\u&', '')
endfunction

function! s:type_name(color) abort
  let name = 'fluoro_' . substitute(tolower(a:color), '[^a-z0-9_]', '_', 'g')
  if has_key(s:color_by_type, name) && s:color_by_type[name] !=# a:color
    let name .= '_' . sha256(a:color)[0:5]
  endif
  return name
endfunction

function! s:define_color(color) abort
  if has_key(s:type_by_color, a:color)
    return s:type_by_color[a:color]
  endif

  let spec = get(s:palette, a:color, a:color)
  let group = ''
  if type(spec) == v:t_string
    let group = spec
  else
    let group = 'Fluoro' . s:capitalize(a:color)
    call s:define_hl(group, spec)
  endif

  let type = s:type_name(a:color)
  if empty(prop_type_get(type))
    call prop_type_add(type, {
          \ 'highlight': group,
          \ 'combine': get(g:, 'fluoro_combine', 1),
          \ 'priority': get(g:, 'fluoro_priority', 10),
          \ })
  endif
  let s:group_by_color[a:color] = group
  let s:type_by_color[a:color] = type
  let s:color_by_type[type] = a:color
  return type
endfunction

function! s:define_hl(group, spec) abort
  let attrs = []
  for key in ['term', 'cterm', 'ctermfg', 'ctermbg', 'gui', 'guifg', 'guibg', 'guisp', 'font']
    if has_key(a:spec, key)
      call add(attrs, key . '=' . a:spec[key])
    endif
  endfor
  if empty(attrs)
    return
  endif
  execute 'highlight default ' . a:group . ' ' . join(attrs, ' ')
endfunction

function! s:error(message) abort
  echohl ErrorMsg
  echomsg 'fluoro: ' . a:message
  echohl None
endfunction

function! s:new_id() abort
  let s:next_id += 1
  return s:next_id
endfunction

function! s:remove_id(id, ...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let notes = s:get_notes(bufnr)
  if has_key(notes, a:id)
    call remove(notes, a:id)
    call s:set_notes(bufnr, notes)
  endif
  if !empty(s:active_note)
        \ && s:active_note.bufnr == bufnr
        \ && s:active_note.id == a:id
    call s:hide_note()
  endif
  return prop_remove({'id': a:id, 'all': 1, 'bufnr': bufnr})
endfunction

function! s:buf_last_line(bufnr) abort
  let info = getbufinfo(a:bufnr)
  if empty(info)
    return 1
  endif
  return max([1, get(info[0], 'linecount', 1)])
endfunction

function! s:buf_line(bufnr, lnum) abort
  let lines = getbufline(a:bufnr, a:lnum)
  return empty(lines) ? '' : lines[0]
endfunction

function! s:byte_len(bufnr, lnum) abort
  let lines = getbufline(a:bufnr, a:lnum)
  return empty(lines) ? 0 : strlen(lines[0])
endfunction

function! s:clamp_col(bufnr, lnum, col) abort
  return max([1, min([a:col, s:byte_len(a:bufnr, a:lnum) + 1])])
endfunction

function! s:normalize_range(sl, sc, el, ec, bufnr) abort
  let last = s:buf_last_line(a:bufnr)
  let sl = max([1, min([a:sl, last])])
  let el = max([1, min([a:el, last])])
  let sc = a:sc
  let ec = a:ec
  if sl > el || (sl == el && sc > ec)
    let [sl, el] = [el, sl]
    let [sc, ec] = [ec, sc]
  endif
  let sc = s:clamp_col(a:bufnr, sl, sc)
  let ec = s:clamp_col(a:bufnr, el, ec)
  if sl == el && ec < sc
    let ec = sc
  endif
  return [sl, sc, el, ec]
endfunction

" The '< and '> marks point at the last selected character, so convert the
" end position to the exclusive column expected by prop_add().
function! s:mark_end_col(lnum, col) abort
  let length = s:byte_len(bufnr('%'), a:lnum)
  if a:col > length
    return length + 1
  endif
  let char = matchstr(getline(a:lnum), '\%' . a:col . 'c.')
  return a:col + strlen(char)
endfunction

function! s:visual_range() abort
  let start = getpos("'<")
  let end = getpos("'>")
  if start[1] <= 0 || end[1] <= 0
    return []
  endif
  if start[1] > line('$')
    return []
  endif
  return s:normalize_range(start[1], start[2], end[1],
        \ s:mark_end_col(end[1], end[2]), bufnr('%'))
endfunction

" Use the visual marks only when they still describe the requested range.
function! s:marks_range(line1, line2) abort
  let start = getpos("'<")
  let end = getpos("'>")
  if start[1] == a:line1 && end[1] == a:line2 && start[1] > 0 && end[1] > 0
    return s:normalize_range(start[1], start[2], end[1],
          \ s:mark_end_col(end[1], end[2]), bufnr('%'))
  endif
  return []
endfunction

" The word under the cursor, falling back to a run of non-blank characters and
" finally to the whole line.
function! s:word_range() abort
  let lnum = line('.')
  let line = getline('.')
  let col = col('.')

  for pattern in ['\k\+', '\S\+']
    let start = 0
    while 1
      let match = matchstrpos(line, pattern, start)
      if match[1] < 0
        break
      endif
      if col >= match[1] + 1 && col <= match[2]
        return [lnum, match[1] + 1, lnum, match[2] + 1]
      endif
      let start = match[2]
    endwhile
  endfor

  return [lnum, 1, lnum, strlen(line) + 1]
endfunction

function! s:pos_cmp(a, b) abort
  if a:a[0] != a:b[0]
    return a:a[0] - a:b[0]
  endif
  return a:a[1] - a:b[1]
endfunction

function! s:covers(item, lnum, col) abort
  let start = [a:item.start_lnum, a:item.start_col]
  let end = [a:item.end_lnum, a:item.end_col]
  let pos = [a:lnum, a:col]
  if s:pos_cmp(start, end) == 0
    return s:pos_cmp(pos, start) == 0
  endif
  return s:pos_cmp(pos, start) >= 0 && s:pos_cmp(pos, end) < 0
endfunction

function! s:overlaps(item, sl, sc, el, ec) abort
  let start = [a:item.start_lnum, a:item.start_col]
  let end = [a:item.end_lnum, a:item.end_col]
  let rstart = [a:sl, a:sc]
  let rend = [a:el, a:ec]
  if s:pos_cmp(start, end) == 0
    return s:pos_cmp(start, rstart) >= 0 && s:pos_cmp(start, rend) < 0
  endif
  return s:pos_cmp(start, rend) < 0 && s:pos_cmp(end, rstart) > 0
endfunction

function! s:item_at(bufnr, lnum, col) abort
  for item in fluoro#items(a:bufnr)
    if s:covers(item, a:lnum, a:col)
      return item
    endif
  endfor
  return {}
endfunction

function! s:item_at_cursor() abort
  return s:item_at(bufnr('%'), line('.'), col('.'))
endfunction

function! s:item_for_id(bufnr, id) abort
  for item in fluoro#items(a:bufnr)
    if item.id == a:id
      return item
    endif
  endfor
  return {}
endfunction

function! s:get_notes(bufnr) abort
  let notes = getbufvar(a:bufnr, 'fluoro_notes', {})
  return type(notes) == v:t_dict ? notes : {}
endfunction

function! s:set_notes(bufnr, notes) abort
  if bufexists(a:bufnr) && bufloaded(a:bufnr)
    call setbufvar(a:bufnr, 'fluoro_notes', a:notes)
  endif
endfunction

function! s:clean_note(text) abort
  return substitute(a:text, '[\r\n\t]\+', ' ', 'g')
endfunction

function! s:show_note(item, bufnr) abort
  let text = s:clean_note(a:item.note)
  if empty(text)
    call s:hide_note()
    return
  endif
  let render = s:render_note(a:item, a:bufnr, text)
  if !empty(s:active_note)
        \ && s:active_note.bufnr == a:bufnr
        \ && s:active_note.id == a:item.id
        \ && s:active_note.lines == render.lines
        \ && s:active_note.pad == render.pad
        \ && s:active_note.lnum == a:item.start_lnum
    return
  endif

  call s:hide_note()
  if !bufexists(a:bufnr) || !bufloaded(a:bufnr)
    return
  endif

  try
    for index in range(len(render.lines))
      call prop_add(a:item.start_lnum, 0, {
            \ 'type': 'fluoro_note',
            \ 'text': render.lines[index],
            \ 'text_align': 'above',
            \ 'text_padding_left': render.pad,
            \ 'bufnr': a:bufnr,
            \ })
    endfor
  catch
    if bufexists(a:bufnr) && bufloaded(a:bufnr)
      call prop_remove({'type': 'fluoro_note', 'all': 1, 'bufnr': a:bufnr})
    endif
    let s:active_note = {}
    return
  endtry

  let s:active_note = {
        \ 'bufnr': a:bufnr,
        \ 'id': a:item.id,
        \ 'lines': render.lines,
        \ 'pad': render.pad,
        \ 'lnum': a:item.start_lnum,
        \ 'popup': 0,
        \ }
  if render.block
    let s:active_note.popup = s:create_label_popup(a:item, render, a:bufnr)
  endif
endfunction

" Build the virtual text for a note.  The 'block' style is a multi-line box:
"   ── Note ─────────────
"     note content
"   ──┬──────────────────
" where ┬ is above the first highlighted character.
function! s:render_note(item, bufnr, text) abort
  let style = get(g:, 'fluoro_note_style', 'block')
  if type(style) == v:t_string && style ==# 'block'
    return s:render_block(a:item, a:bufnr, a:text)
  endif
  return {
        \ 'lines': [s:format_note(a:text)],
        \ 'pad': 1,
        \ 'block': 0,
        \ }
endfunction

function! s:render_block(item, bufnr, text) abort
  let label = get(g:, 'fluoro_note_label', 'Note')
  let head = '── ' . label . ' '
  let width = max([s:lines_width(a:item, a:bufnr) + 2, strdisplaywidth(head)])
  let top = head . repeat('─', max([0, width - strdisplaywidth(head)]))

  let lines = [top]
  for line in s:wrap_text(a:text, max([1, width - 1]))
    call add(lines, ' ' . line
          \ . repeat(' ', max([0, width - 1 - strdisplaywidth(line)])))
  endfor

  let start_display = s:display_col(a:bufnr, a:item.start_lnum, a:item.start_col)
  let notch = max([1, min([start_display, width])])
  call add(lines, repeat('─', notch - 1) . '┬'
        \ . repeat('─', max([0, width - notch])))

  return {
        \ 'lines': lines,
        \ 'pad': 0,
        \ 'block': 1,
        \ 'label': label,
        \ 'start_display': start_display,
        \ 'group': get(s:group_by_color, a:item.color, 'FluoroNote'),
        \ }
endfunction

" Width of the widest line touched by the highlight.
function! s:lines_width(item, bufnr) abort
  let widths = []
  for lnum in range(a:item.start_lnum, a:item.end_lnum)
    call add(widths, strdisplaywidth(s:buf_line(a:bufnr, lnum)))
  endfor
  return max(widths + [0])
endfunction

" One-based display column of a byte column.
function! s:display_col(bufnr, lnum, col) abort
  let line = s:buf_line(a:bufnr, a:lnum)
  let prefix = strpart(line, 0, max([0, a:col - 1]))
  return strdisplaywidth(prefix) + 1
endfunction

" Word-aware wrapping; words longer than the width are hard-wrapped.
function! s:wrap_text(text, width) abort
  let width = max([1, a:width])
  let lines = []
  let current = ''
  for word in split(a:text, '\s\+')
    if empty(current)
      let current = word
    elseif strdisplaywidth(current . ' ' . word) <= width
      let current .= ' ' . word
    else
      call add(lines, current)
      let current = word
    endif
  endfor
  if !empty(current)
    call add(lines, current)
  endif
  if empty(lines)
    let lines = ['']
  endif

  let wrapped = []
  for line in lines
    while strdisplaywidth(line) > width
      let chunk = ''
      let used = 0
      let rest = ''
      let index = 0
      for char in split(line, '\zs')
        let char_width = strdisplaywidth(char)
        if used + char_width > width
          let rest = strcharpart(line, index)
          break
        endif
        let chunk .= char
        let used += char_width
        let index += 1
      endfor
      if empty(chunk)
        let chunk = strcharpart(line, 0, 1)
        let rest = strcharpart(line, 1)
      endif
      call add(wrapped, chunk)
      let line = rest
    endwhile
    call add(wrapped, line)
  endfor
  return wrapped
endfunction

" Frame a note in a single line of virtual text.  g:fluoro_note_style is
" either the name of a preset or a two-item List [left, right].
function! s:format_note(text) abort
  let label = get(g:, 'fluoro_note_prefix', '✎ ') . a:text
  let presets = {
        \ 'plain':      label,
        \ 'bracket':    '【 ' . label . ' 】',
        \ 'square':     '[ ' . label . ' ]',
        \ 'bar':        '▌ ' . label,
        \ 'pill':       '▐ ' . label . ' ▌',
        \ 'box':        '╭─ ' . label . ' ─╮',
        \ 'box-bottom': '╰─ ' . label . ' ─╯',
        \ 'double':     '╔═ ' . label . ' ═╗',
        \ 'dashed':     '┄┄ ' . label . ' ┄┄',
        \ 'callout':    '▼ ' . label,
        \ 'arrow':      '▸ ' . label,
        \ 'notch':      '──────⌄────── ' . label,
        \ 'notch-triangle': '──────▾────── ' . label,
        \ 'notch-double': '══════╦══════ ' . label,
        \ 'notch-heavy': '━━━━━━┳━━━━━━ ' . label,
        \ 'notch-diagonal': '──────╲╱────── ' . label,
        \ }
  let style = get(g:, 'fluoro_note_style', 'block')
  if type(style) == v:t_list
    if len(style) >= 2
      return style[0] . label . style[1]
    elseif len(style) == 1
      return style[0] . label
    endif
    return label
  endif
  return get(presets, style, presets.plain)
endfunction

" Virtual text can only use one highlight group per line, so draw the label in
" the highlight color with a tiny popup laid exactly over the word "Note".
function! s:create_label_popup(item, render, bufnr) abort
  if !a:render.block || empty(get(a:render, 'label', ''))
    return 0
  endif
  if !exists('*popup_create')
    return 0
  endif

  let wins = win_findbuf(a:bufnr)
  if empty(wins)
    return 0
  endif
  let winid = index(wins, win_getid()) >= 0 ? win_getid() : wins[0]
  let line_length = s:byte_len(a:bufnr, a:item.start_lnum)
  let col = max([1, min([a:item.start_col, max([1, line_length])])])
  let position = screenpos(winid, a:item.start_lnum, col)
  if position.row <= 0 || position.col <= 0
    return 0
  endif

  let text_start = position.col - (a:render.start_display - 1)
  let row = position.row - len(a:render.lines)
  let col = text_start + 3
  if row < 1 || col < 1
    return 0
  endif

  let group = empty(a:render.group) ? 'FluoroNote' : a:render.group
  try
    return popup_create(a:render.label, {
          \ 'line': row,
          \ 'col': col,
          \ 'pos': 'topleft',
          \ 'highlight': group,
          \ 'border': [0, 0, 0, 0],
          \ 'padding': [0, 0, 0, 0],
          \ 'wrap': 0,
          \ 'zindex': 300,
          \ 'mapping': 0,
          \ 'scrollbar': 0,
          \ 'close': 'none',
          \ })
  catch
    return 0
  endtry
endfunction

function! s:hide_note() abort
  if empty(s:active_note)
    return
  endif
  let bufnr = s:active_note.bufnr
  let popup = get(s:active_note, 'popup', 0)
  let s:active_note = {}
  if popup > 0 && exists('*popup_getpos') && !empty(popup_getpos(popup))
    call popup_close(popup)
  endif
  if bufexists(bufnr) && bufloaded(bufnr)
    call prop_remove({'type': 'fluoro_note', 'all': 1, 'bufnr': bufnr})
  endif
endfunction

function! s:define_note_hl() abort
  highlight default FluoroNote ctermbg=236 ctermfg=253 guibg=#262626 guifg=#f0f0f0
endfunction

function! s:compare_items(a, b) abort
  if a:a.start_lnum != a:b.start_lnum
    return a:a.start_lnum - a:b.start_lnum
  endif
  if a:a.start_col != a:b.start_col
    return a:a.start_col - a:b.start_col
  endif
  return a:a.end_lnum - a:b.end_lnum
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set fdm=marker sw=2 sts=2 et:
