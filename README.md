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
# Showing defaults
require'nvim-lightbulb'.update_lightbulb {
  sign_priority = 10
}
```

##### Modify the [lightbulb sign](https://neovim.io/doc/user/sign.html#:sign-define):

> Fill `text`, `texthl`, `linehl`, and `numhl` according to your preferences

VimScript:
```vim
call sign_define("LightBulbSign", { text = "", texthl = "", linehl="", numhl="" })
```

Lua:
```lua
vim.fn.sign_define("LightBulbSign", { text = "", texthl = "", linehl="", numhl="" })
```
