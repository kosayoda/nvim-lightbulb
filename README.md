# nvim-lightbulb

VSCode 💡 for neovim's built-in LSP.

![](https://s2.gifyu.com/images/nvim-lightbulb.gif)

> Code Action selection window shown in the gif is [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Introduction/Rationale
The plugin shows a lightbulb in the sign column whenever a `textDocument/codeAction` is available at the current cursor position.

This makes code actions both [discoverable and efficient](https://rust-analyzer.github.io/blog/2020/09/28/how-to-make-a-light-bulb.html#the-mighty), as code actions can be available even when there are no visible diagnostics (warning, information, hints etc.).

## Getting Started

### Prerequisites
- [neovim](https://github.com/neovim/neovim) with LSP capabilities.

### Installation
Just like any other plugin.

Example using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'kosayoda/nvim-lightbulb'
```

### Usage
Call `require('nvim-lightbulb').update_lightbulb()` whenever you want to show a lightbulb if a code action is available at the current cursor position. Example with an [`autocmd`](https://neovim.io/doc/user/autocmd.html) for all filetypes:

VimScript:
```vim
autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()
```

Lua:
```lua
vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
```


### Configuration

##### Available options:
```lua
-- Showing defaults
require'nvim-lightbulb'.update_lightbulb {
    sign = {
        enabled = true,
        -- Priority of the gutter sign
        priority = 10,
    },
    float = {
        enabled = false,
        -- Text to show in the popup float
        text = "💡",
        -- Available keys for window options:
        -- - height     of floating window
        -- - width      of floating window
        -- - wrap_at    character to wrap at for computing height
        -- - max_width  maximal width of floating window
        -- - max_height maximal height of floating window
        -- - pad_left   number of columns to pad contents at left
        -- - pad_right  number of columns to pad contents at right
        -- - pad_top    number of lines to pad contents at top
        -- - pad_bottom number of lines to pad contents at bottom
        -- - offset_x   x-axis offset of the floating window
        -- - offset_y   y-axis offset of the floating window
        -- - anchor     Corner of float to place at the cursor (NW, NE, SW, SE)
        win_opts = {},
    }
}
```

##### Modify the [lightbulb sign](https://neovim.io/doc/user/sign.html#:sign-define):

> Fill `text`, `texthl`, `linehl`, and `numhl` according to your preferences

VimScript:
```vim
call sign_define('LightBulbSign', { text = "", texthl = "", linehl="", numhl="" })
```

Lua:
```lua
vim.fn.sign_define('LightBulbSign', { text = "", texthl = "", linehl="", numhl="" })
```

##### Modify the lightbulb float window colors

>  Fill `ctermfg`, `ctermbg`, `guifg`, `guibg` according to your preferences

VimScript:
```vim
highlight LightBulbFloatWin ctermfg= ctermbg= guifg= guibg=
augroup HighlightOverride
  autocmd!
  au ColorScheme * highlight LightBulbFloatWin ctermfg= ctermbg= guifg= guibg=
augroup END
```

Lua:
```lua
vim.api.nvim_command('highlight LightBulbFloatWin ctermfg= ctermbg= guifg= guibg=')
```
