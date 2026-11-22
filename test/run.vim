" Minimal headless test suite.  Run with:
"   vim -Nu NONE -es -S test/run.vim
" Results are written to test/results.txt.

set nocompatible
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let s:tmp = s:root . '/test/tmp'
call delete(s:tmp, 'rf')
call mkdir(s:tmp, 'p')
let g:fluoro_storage_dir = s:tmp . '/store'
let g:fluoro_default_mappings = 0
let g:fluoro_autosave = 0
let g:fluoro_autoload = 0
execute 'set runtimepath^=' . fnameescape(s:root)
runtime plugin/fluoro.vim

let v:errors = []

function! s:reset() abort
  enew!
  call setline(1, ['alpha beta gamma', 'delta epsilon zeta', 'eta theta iota', ''])
  execute 'file ' . fnameescape(s:tmp . '/buffer.txt')
  call fluoro#clear()
endfunction

" --- palette / setup -------------------------------------------------------
call assert_equal('yellow', fluoro#current_color())
call assert_true(index(fluoro#colors(), 'yellow') >= 0)
call assert_equal(['yellow', 'green', 'blue', 'pink'], fluoro#colors())
call assert_equal('blue', fluoro#resolve_color('blue', 1))
call assert_equal('', fluoro#resolve_color('nope', 1))
call assert_true(index(fluoro#complete('y', '', 0), 'yellow') >= 0)

" --- add / items -----------------------------------------------------------
call s:reset()
let s:id = fluoro#add(1, 7, 1, 11, 'yellow')
call assert_true(s:id > 0)
let s:items = fluoro#items()
call assert_equal(1, len(s:items))
call assert_equal('yellow', s:items[0].color)
call assert_equal(1, s:items[0].start_lnum)
call assert_equal(7, s:items[0].start_col)
call assert_equal(1, s:items[0].end_lnum)
call assert_equal(11, s:items[0].end_col)
call assert_equal(1, fluoro#count())
call assert_equal('F1', fluoro#status())

" --- multi-line ranges -----------------------------------------------------
call s:reset()
call fluoro#add(1, 3, 3, 4, 'green')
let s:item = fluoro#items()[0]
call assert_equal(1, s:item.start_lnum)
call assert_equal(3, s:item.start_col)
call assert_equal(3, s:item.end_lnum)
call assert_equal(4, s:item.end_col)

" --- toggling --------------------------------------------------------------
call s:reset()
call fluoro#toggle_range(1, 7, 1, 11, 'yellow')
call assert_equal(1, fluoro#count())
call fluoro#toggle_range(1, 7, 1, 11, 'yellow')
call assert_equal(0, fluoro#count())

call fluoro#toggle_range(1, 1, 1, 6, 'yellow')
call fluoro#toggle_range(1, 1, 1, 6, 'blue')
let s:items = fluoro#items()
call assert_equal(1, len(s:items))
call assert_equal('blue', s:items[0].color)

" --- multibyte columns -----------------------------------------------------
call s:reset()
call setline(1, 'héllo wörld')
let s:start = stridx(getline(1), 'wörld') + 1
let s:end = s:start + strlen('wörld')
call fluoro#add(1, s:start, 1, s:end, 'pink')
let s:items = fluoro#items()
call assert_equal(s:start, s:items[0].start_col)
call assert_equal(s:end, s:items[0].end_col)
call cursor(1, s:start + 1)
let s:here = fluoro#info()
call assert_equal(1, len(s:here))
call assert_equal('pink', s:here[0].color)

" --- zero width ------------------------------------------------------------
call s:reset()
call fluoro#add(4, 1, 4, 1, 'green')
let s:items = fluoro#items()
call assert_equal(1, len(s:items))
call assert_equal(s:items[0].start_col, s:items[0].end_col)

" --- erase under cursor ----------------------------------------------------
call s:reset()
call fluoro#add(1, 7, 1, 11, 'yellow')
call cursor(1, 9)
call fluoro#erase_cursor()
call assert_equal(0, fluoro#count())

" --- erase range -----------------------------------------------------------
call s:reset()
call fluoro#add(1, 1, 1, 6, 'yellow')
call fluoro#add(2, 1, 2, 6, 'green')
call fluoro#add(3, 1, 3, 4, 'blue')
call fluoro#erase_range(1, 5, 2, 2)
call assert_equal(1, fluoro#count())

" --- navigation ------------------------------------------------------------
call s:reset()
call fluoro#add(1, 1, 1, 3, 'yellow')
call fluoro#add(2, 1, 2, 3, 'green')
call fluoro#add(3, 1, 3, 3, 'blue')
call cursor(1, 1)
call fluoro#next()
call assert_equal(2, line('.'))
call fluoro#next()
call assert_equal(3, line('.'))
call fluoro#prev()
call assert_equal(2, line('.'))

" From inside a highlight, prev goes to the previous highlight, not its start.
call cursor(2, 2)
call fluoro#prev()
call assert_equal(1, line('.'))
call cursor(2, 2)
call fluoro#prev()
call assert_equal(1, line('.'))
call cursor(1, 2)
call fluoro#prev()
call assert_equal(3, line('.'))

" Navigation wraps around by default.
call cursor(3, 1)
call fluoro#next()
call assert_equal(1, line('.'))
call fluoro#prev()
call assert_equal(3, line('.'))

" --- cycling colors --------------------------------------------------------
call s:reset()
call fluoro#add(1, 1, 1, 6, 'yellow')
call cursor(1, 2)
call fluoro#cycle_color()
call assert_equal('green', fluoro#items()[0].color)
call assert_equal(1, fluoro#count())

" --- save / load -----------------------------------------------------------
call s:reset()
call fluoro#add(1, 7, 1, 11, 'yellow')
call fluoro#add(2, 1, 3, 4, 'pink')
call fluoro#set_note(fluoro#items()[0].id, 'remember this')
call assert_equal(2, fluoro#store#save())
let s:store_file = fluoro#store#file_for(bufnr('%'))
call assert_true(filereadable(s:store_file))
call fluoro#clear()
call assert_equal(0, fluoro#count())
call assert_equal(2, fluoro#store#load())
let s:items = fluoro#items()
call assert_equal(2, len(s:items))
call assert_equal('yellow', s:items[0].color)
call assert_equal('pink', s:items[1].color)
call assert_equal(3, s:items[1].end_lnum)
call assert_equal('remember this', s:items[0].note)

" --- clear buffer removes storage -----------------------------------------
call s:reset()
call fluoro#add(1, 1, 1, 3, 'blue')
call fluoro#store#save()
call assert_true(filereadable(fluoro#store#file_for(bufnr('%'))))
call fluoro#clear_buffer()
call assert_false(filereadable(fluoro#store#file_for(bufnr('%'))))

" --- unnamed buffers are not persisted ------------------------------------
enew!
call setline(1, ['unnamed'])
call assert_equal('', fluoro#store#file_for(bufnr('%')))
call assert_equal(0, fluoro#store#save())
call fluoro#add(1, 1, 1, 7, 'pink')
call assert_equal(1, fluoro#count())

" --- command / visual mark ranges -----------------------------------------
call s:reset()
call setpos("'<", [0, 1, 7, 0])
call setpos("'>", [0, 1, 10, 0])
call fluoro#cmd_highlight(2, 1, 1, 'yellow')
let s:items = fluoro#items()
call assert_equal(1, len(s:items))
call assert_equal(7, s:items[0].start_col)
call assert_equal(11, s:items[0].end_col)

" Marks that do not match the range mean whole lines.
call fluoro#cmd_highlight(2, 1, 2, 'green')
let s:items = fluoro#items()
let s:line_item = filter(copy(s:items), 'v:val.start_lnum == 1 && v:val.start_col == 1')[0]
call assert_equal('green', s:line_item.color)
call assert_equal(1, s:line_item.start_col)
call assert_equal(2, s:line_item.end_lnum)
call assert_equal(19, s:line_item.end_col)

" No range highlights the word under the cursor.
call cursor(1, 9)
call fluoro#cmd_highlight(0, 1, 1, 'pink')
let s:items = fluoro#items()
call assert_equal('pink', s:items[-1].color)
call assert_equal(7, s:items[-1].start_col)
call assert_equal(11, s:items[-1].end_col)

call fluoro#highlight_visual('green')
let s:items = fluoro#items()
let s:marked_item = filter(copy(s:items), 'v:val.start_col == 7')[0]
call assert_equal('green', s:marked_item.color)
call assert_equal(11, s:marked_item.end_col)

" --- custom colors ---------------------------------------------------------
call s:reset()
highlight hl_y ctermbg=11 ctermfg=0
let s:id = fluoro#add(1, 1, 1, 5, 'hl_y')
call assert_true(s:id > 0)
call assert_equal('hl_y', fluoro#items()[0].color)
call fluoro#store#save()
call fluoro#clear()
call assert_equal(1, fluoro#store#load())
call assert_equal('hl_y', fluoro#items()[0].color)

" --- colorscheme refresh ---------------------------------------------------
call fluoro#apply_highlights()
call assert_equal(1, hlexists('FluoroYellow'))

" --- exported data is valid JSON ------------------------------------------
call s:reset()
call fluoro#add(1, 7, 2, 4, 'blue')
call fluoro#store#save()
let s:raw = join(readfile(fluoro#store#file_for(bufnr('%'))), "\n")
let s:data = json_decode(s:raw)
call assert_equal(1, s:data.version)
call assert_equal(1, len(s:data.highlights))
call assert_equal('blue', s:data.highlights[0].color)
call assert_equal([2, 4], s:data.highlights[0].end)

" --- `,,` cycle-or-toggle ------------------------------------------------
call s:reset()
call fluoro#current_color('yellow')
call cursor(1, 9)
call assert_equal('yellow', fluoro#cycle_or_toggle())
call assert_equal(1, fluoro#count())
call assert_equal(7, fluoro#items()[0].start_col)
call assert_equal('green', fluoro#cycle_or_toggle())
call assert_equal('blue', fluoro#cycle_or_toggle())
call assert_equal('pink', fluoro#cycle_or_toggle())
call assert_equal('pink', fluoro#items()[0].color)
call assert_equal('', fluoro#cycle_or_toggle())
call assert_equal(0, fluoro#count())

" Starting from a custom color goes back to the first palette color.
call s:reset()
highlight hl_y ctermbg=11 ctermfg=0
call fluoro#add(1, 7, 1, 11, 'hl_y')
call cursor(1, 8)
call assert_equal('yellow', fluoro#cycle_or_toggle())
call assert_equal('yellow', fluoro#items()[0].color)

" --- notes ----------------------------------------------------------------
call s:reset()
let s:id = fluoro#add(1, 7, 1, 11, 'yellow')
call assert_equal('', fluoro#get_note(s:id))
call fluoro#set_note(s:id, 'look here')
call assert_equal('look here', fluoro#get_note(s:id))
call assert_equal('look here', fluoro#items()[0].note)

" Newlines and tabs are flattened, and long text is wrapped into the box.
call fluoro#set_note(s:id, "first\nsecond\tthird")
call assert_equal('first second third', fluoro#get_note(s:id))

" The note is displayed above the start line while the cursor is inside.
call cursor(1, 8)
call fluoro#note_cursor()
let s:notes_props = prop_list(1, {'types': ['fluoro_note']})
let s:note_texts = map(copy(s:notes_props), 'v:val.text')
call assert_equal(4, len(s:notes_props))
call assert_true(index(s:note_texts, '── Note ──────────') >= 0)
call assert_true(index(s:note_texts, '──────┬───────────') >= 0)
call assert_true(index(s:note_texts, ' first second     ') >= 0)

" The frame style is configurable, including custom pairs.
let g:fluoro_note_style = 'double'
call fluoro#note_hide()
call fluoro#note_cursor()
call assert_equal('╔═ ✎ first second third ═╗',
      \ prop_list(1, {'types': ['fluoro_note']})[0].text)
let g:fluoro_note_style = ['〈 ', ' 〉']
call fluoro#note_hide()
call fluoro#note_cursor()
call assert_equal('〈 ✎ first second third 〉',
      \ prop_list(1, {'types': ['fluoro_note']})[0].text)
let g:fluoro_note_style = 'notch'
call fluoro#note_hide()
call fluoro#note_cursor()
call assert_equal('──────⌄────── ✎ first second third',
      \ prop_list(1, {'types': ['fluoro_note']})[0].text)
unlet g:fluoro_note_style
call fluoro#note_hide()
call fluoro#note_cursor()
call cursor(2, 1)
call fluoro#note_cursor_leave()
call assert_equal(0, len(prop_list(1, {'types': ['fluoro_note']})))
call cursor(1, 8)
call fluoro#note_cursor()
call fluoro#clear()
call assert_equal(0, len(prop_list(1, {'types': ['fluoro_note']})))
call assert_equal('', fluoro#get_note(s:id))

" A note survives recoloring and cycling.
call s:reset()
let s:id = fluoro#add(1, 7, 1, 11, 'yellow')
call fluoro#set_note(s:id, 'keep me')
call cursor(1, 8)
call fluoro#cycle_color()
call assert_equal('keep me', fluoro#items()[0].note)
call fluoro#cycle_color()
call fluoro#cycle_or_toggle()
call assert_equal('keep me', fluoro#items()[0].note)
call fluoro#cycle_or_toggle()
call assert_equal(0, fluoro#count())
call assert_equal('', fluoro#get_note(s:id))

" The :FluoroNote command sets a literal note.
call s:reset()
call fluoro#add(1, 7, 1, 11, 'blue')
call cursor(1, 8)
execute 'FluoroNote a useful reminder'
call assert_equal('a useful reminder', fluoro#items()[0].note)
execute 'FluoroNoteClear'
call assert_equal('', fluoro#items()[0].note)

" A note on a multi-line highlight is displayed above its first line.
call s:reset()
call fluoro#add(2, 1, 3, 4, 'green')
call fluoro#set_note(fluoro#items()[0].id, 'multi-line note')
call cursor(3, 2)
call fluoro#note_cursor()
call assert_true(len(prop_list(2, {'types': ['fluoro_note']})) > 0)
call assert_equal(0, len(prop_list(3, {'types': ['fluoro_note']})))
call fluoro#note_hide()

" A linewise highlight gets a box as wide as the widest line plus two.
call s:reset()
call fluoro#add(1, 1, 2, 19, 'blue')
call fluoro#set_note(fluoro#items()[0].id, 'linewise')
call cursor(1, 1)
call fluoro#note_cursor()
let s:note_texts = map(copy(prop_list(1,
      \ {'types': ['fluoro_note']})), 'v:val.text')
call assert_true(index(s:note_texts, '── Note ────────────') >= 0)
call assert_true(index(s:note_texts, '┬───────────────────') >= 0)
call fluoro#note_hide()

" --- results ---------------------------------------------------------------
if empty(v:errors)
  call writefile(['PASS'], s:root . '/test/results.txt')
  qall!
else
  call writefile(['FAIL: ' . len(v:errors) . ' error(s)'] + v:errors,
        \ s:root . '/test/results.txt')
  cquit!
endif
