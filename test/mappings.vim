" Verify the plugin loads with default mappings and that `,,` works.
set nocompatible
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let g:fluoro_storage_dir = s:root . '/test/tmp/store'
let g:fluoro_autosave = 0
let g:fluoro_autoload = 0
execute 'set runtimepath^=' . fnameescape(s:root)
runtime plugin/fluoro.vim

let v:errors = []
enew!
execute 'file ' . fnameescape('/tmp/fluoro_mapping_test_' . getpid() . '.txt')
call setline(1, ['alpha beta gamma', 'delta epsilon zeta'])

call assert_equal('<Plug>(fluoro-cycle)', maparg(',,', 'n'))
call assert_equal('<Plug>(fluoro-highlight-first)', maparg(',,', 'x'))
call assert_equal('<Plug>(fluoro-note)', maparg(',n', 'n'))
call assert_equal('<Plug>(fluoro-note-clear)', maparg(',N', 'n'))
call assert_equal('<Plug>(fluoro-next)', maparg(']f', 'n'))
call assert_equal('<Plug>(fluoro-prev)', maparg('[f', 'n'))
call assert_equal('<Plug>(fluoro-highlight-first)', maparg('gF', 'x'))
call assert_true(!empty(maparg('<LeftMouse>', 'n')))

call cursor(1, 9)
normal ,,
call assert_equal(1, fluoro#count())
call assert_equal('yellow', fluoro#items()[0].color)
call assert_equal(7, fluoro#items()[0].start_col)
call assert_equal(11, fluoro#items()[0].end_col)

normal ,,
call assert_equal('green', fluoro#items()[0].color)
normal ,,
normal ,,
call assert_equal('pink', fluoro#items()[0].color)
normal ,,
call assert_equal(0, fluoro#count())

" Visual selection: select 'beta' and press `,,`.
call setpos('.', [0, 1, 7, 0])
execute "normal! v3l"
call feedkeys(',,', 'xt')
call assert_equal(1, fluoro#count())
call assert_equal('yellow', fluoro#items()[0].color)
call assert_equal(7, fluoro#items()[0].start_col)
call assert_equal(11, fluoro#items()[0].end_col)

if empty(v:errors)
  call writefile(['PASS'], s:root . '/test/results-mappings.txt')
  qall!
else
  call writefile(['FAIL: ' . len(v:errors) . ' error(s)'] + v:errors,
        \ s:root . '/test/results-mappings.txt')
  cquit!
endif
