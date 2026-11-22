# fluoro.vim

Fluorescent highlights that stick to your text.

Fluoro marks ranges with real Vim [text properties](https://vimhelp.org/textprop.txt.html): the
highlights move with the text when you edit above them, survive undo/redo, and
come back when you reopen the file.

The palette is the four classic fluoro pen colors, and new highlights always
start with yellow:

```
yellow -> green -> blue -> pink -> off
```

## Requirements

- Vim with `+textprop` (Vim 8.2 or later)
- No other plugins
- Neovim is not supported (it has no text properties)

## Install

With vim-plug:

```vim
Plug 'edouardp/fluoro'
```

Then `:PlugInstall`, or add the checkout to `runtimepath` yourself:

```vim
set runtimepath^=~/path/to/fluoro
runtime plugin/fluoro.vim
```

For a local checkout there is also:

```sh
make install     # symlink into ~/.vim/pack/plugins/start/fluoro
make uninstall
make dev         # open Vim with this checkout on 'runtimepath'
```

## Use it

| Mode   | Keys                | What happens                                         |
| ------ | ------------------- | ---------------------------------------------------- |
| Visual | `,,`                | Highlight the selection in yellow, leave Visual mode |
| Normal | `,,`                | Highlight the word under the cursor in yellow        |
| Normal | `,,` on a highlight | Cycle yellow → green → blue → pink → remove          |
| Normal | `]f` / `[f`         | Jump to the next / previous highlight                |
| Normal | `:FluoroInfo`       | Describe the highlight under the cursor              |
| Normal | `,n`                | Attach a note to the highlight under the cursor      |
| Normal | `,N`                | Remove the note from that highlight                  |
| Normal | `:FluoroNote`       | Same as `,n`                                         |
| Any    | `:FluoroList`       | Put the buffer's highlights in the quickfix list     |

Visual mode on an existing highlight recolors it (or toggles it off if it is
already yellow).

Explicit commands:

```vim
:'<,'>FluoroHighlight green
:FluoroHighlight blue          " word under the cursor
:FluoroErase                   " remove highlight under the cursor
:FluoroEraseBuffer             " remove all in this buffer
:FluoroEraseEverything         " remove all everywhere
:FluoroNext 3                  " jump three highlights forward
:FluoroColor pink              " set the pen used by :FluoroHighlight
```

## Notes

A highlight can carry a note.  It is displayed as virtual text just above the
first line of the highlight, and disappears when the pointer leaves:

```vim
:FluoroNote call this again after the refactor
:FluoroNote            " prompts, prefilled with the current note
:FluoroNoteClear       " remove the note
:FluoroNoteShow        " show it now
```

- **GUI:** hovering the mouse over a highlight shows its note (uses
  `<MouseMove>`; fluoro enables `'mousemoveevent'` when needed).  Clicking a
  highlight opens its note immediately (the `<LeftMouse>` mapping is only
  installed if that key is not already mapped).
- **Terminal:** Vim cannot report mouse movement, so the note appears after
  `CursorHold` (when the cursor has been still for `'updatetime'` ms) and is
  hidden as soon as the cursor leaves the highlight.

Notes are saved with their highlights and survive reloads.  Newlines and tabs
are flattened to spaces.

### Framing

The default style is `block`, a multi-line box above the highlight:

```text
── Note ────────────────────────────────
 a body of note text, wrapped as needed
──┬────────────────────────────────────
```

The box always starts in the first column.  Its width is the width of the
widest line touched by the highlight + 2, the content is indented one space,
and `┬` points at the first column of the highlighted text.  Only the word
`Note` uses the highlight's color; the line-drawing characters use the note
style.  Because Vim virtual text only supports one highlight group per line,
the colored label is a tiny popup overlay (requires `+popupwin`); without it
the label uses the normal note style.  Change the label with
`g:fluoro_note_label` (default `Note`).

If you prefer a single-line frame, pick a preset with `g:fluoro_note_style`
(default `block`):

| `g:fluoro_note_style` | Looks like                   |
| --------------------- | ---------------------------- |
| `plain`               | `✎ note text`                |
| `bracket`             | `【 ✎ note text 】`          |
| `square`              | `[ ✎ note text ]`            |
| `bar`                 | `▌ ✎ note text`              |
| `pill`                | `▐ ✎ note text ▌`            |
| `box`                 | `╭─ ✎ note text ─╮`          |
| `box-bottom`          | `╰─ ✎ note text ─╯`          |
| `double`              | `╔═ ✎ note text ═╗`          |
| `dashed`              | `┄┄ ✎ note text ┄┄`          |
| `callout`             | `▼ ✎ note text`              |
| `arrow`               | `▸ ✎ note text`              |
| `notch`               | `──────⌄────── ✎ note text`  |
| `notch-triangle`      | `──────▾────── ✎ note text`  |
| `notch-double`        | `══════╦══════ ✎ note text`  |
| `notch-heavy`         | `━━━━━━┳━━━━━━ ✎ note text`  |
| `notch-diagonal`      | `──────╲╱────── ✎ note text` |

Custom frames are just a left/right pair:

```vim
let g:fluoro_note_style = ['〈 ', ' 〉']
let g:fluoro_note_prefix = 'NOTE: '
let g:fluoro_note_label = 'Note'
```

Run `:help fluoro` for the full reference.

## Configuration

All options are optional:

```vim
let g:fluoro_default_mappings = 1   " ,, ,n ,N ]f [f gF
let g:fluoro_storage_dir = '~/.vim/fluoro'
let g:fluoro_autosave = 1
let g:fluoro_autoload = 1
let g:fluoro_combine = 1            " combine with syntax highlighting
let g:fluoro_priority = 10
let g:fluoro_wrap = 1               " wrap :FluoroNext / :FluoroPrev
let g:fluoro_current_color = 'yellow'
let g:fluoro_note_cursor = 1        " terminal cursor fallback
let g:fluoro_note_mouse = 1         " GUI mouse hover
let g:fluoro_note_prefix = '✎ '
let g:fluoro_note_style = 'box'     " see the framing table above
```

Customize or extend the palette:

```vim
let g:fluoro_palette = {
      \ 'yellow': {'ctermbg': '226', 'ctermfg': '16',
      \            'guibg': '#f6f65a', 'guifg': '#101010'},
      \ 'review': 'Search',
      \ }
```

Palette entries are appended after the four defaults.  Any highlight group
name also works as an ad-hoc color: `:'<,'>FluoroHighlight hl_y`.

Remap the visual action if `,,` is not for you:

```vim
xmap <Leader>f <Plug>(fluoro-highlight-first)
```

Available `<Plug>` mappings: `fluoro-cycle`, `fluoro-highlight`,
`fluoro-highlight-first`, `fluoro-highlight-{color}`, `fluoro-erase`,
`fluoro-next`, `fluoro-prev`, `fluoro-info`, `fluoro-note`,
`fluoro-note-clear`, `fluoro-note-show`, `fluoro-note-click`.

## Persistence

Highlights and notes are saved as JSON per file under `g:fluoro_storage_dir`
on write, buffer unload, and Vim exit, and restored when the file is read.  Unnamed and
special buffers are never persisted.

Note that positions are line/byte-column pairs.  If you edit a file outside of
Vim, stored positions can drift.  Inside Vim, the text properties adjust
themselves as you edit.

## Statusline

```vim
set statusline+=%{fluoro#status()}
```

Shows `F3` when the buffer has three highlights, and nothing otherwise.

## How it works

Fluoro defines one text property type per palette color (`fluoro_yellow`, ...)
and attaches properties with `prop_add()` using byte columns.  Everything is
enumerated back out with `prop_list()`, so the buffer itself is the single
source of truth; the plugin never keeps a second copy of positions in memory.
That is why edits, undo, and buffer switching behave correctly.

## Development

```sh
make            # list targets
make test       # headless unit + mapping tests
make lint       # clean plugin load and help-tag validation
make check      # lint + test
make doc        # generate doc/tags for :help fluoro
make tags       # ctags (Universal Ctags)
make clean
```

The tests can also be run directly:

```sh
vim -Nu NONE -es -S test/run.vim
cat test/results.txt   # PASS, or the failed assertions
```

## License

MIT.  See [LICENSE](LICENSE).
