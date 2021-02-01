# nvim-lightbulb

VSCode 💡 for neovim's built-in LSP.

## Introduction/Rationale
The plugin shows a lightbulb in the sign column whenever a `textDocument/codeAction` is available at the current cursor position.

This makes code actions both [discoverable and efficient](https://rust-analyzer.github.io/blog/2020/09/28/how-to-make-a-light-bulb.html#the-mighty), as code actions can be available even when there are no visible diagnostics (warning, information, hints etc.).

## Usage

### Prerequisites
- [neovim](https://github.com/neovim/neovim) with LSP capabilities.

### Installation
Just like any other plugin.

Example using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'kosayoda/nvim-lightbulb'
```

### Quickstart
Call `require('nvim-lightbulb').update_lightbulb()` whenever you want to show a lightbulb if a code action is available at the current cursor position. Example with an [`autocmd`](https://neovim.io/doc/user/autocmd.html):

VimScript:
```vim
autocmd CursorHold * lua require'nvim-lightbulb'.update_lightbulb()
```

Lua:
```lua
vim.cmd [[autocmd CursorHold * lua require'nvim-lightbulb'.update_lightbulb()]]
```

### Configuration
##### Modify the [lightbulb sign](https://neovim.io/doc/user/sign.html#:sign-define):

VimScript:
```vim
call sign_define("LightBulbSign", { text = "💡", texthl = "SignColumn" })
```

Lua:
```lua
vim.fn.sign_define("LightBulbSign", { text = "💡", texthl = "SignColumn" })
```

##### Set the [sign priority](https://neovim.io/doc/user/sign.html#sign-priority):

VimScript:
```lua
lua require'nvim-lightbulb'.config { sign_priority = 100 }
```

Lua:
```lua
require'nvim-lightbulb'.config { sign_priority = 100 }
```
