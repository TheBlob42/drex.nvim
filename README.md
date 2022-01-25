# DREX

Another **D**i**R**ectory **EX**plorer for Neovim

![drex](./assets/drex.png)
For showcase GIFs see [here](https://github.com/TheBlob42/drex.nvim/wiki/Showcase)

- easily navigate through your file system
- split window and project drawer support
- add, copy, move, rename and delete elements
- mark and operate on multiple elements
- automatic file system synchronization
- powered by [libuv](https://github.com/luvit/luv/blob/master/docs.md)

## Installation

> DREX requires Neovim version ≥ 0.5

Install DREX with your favorite plugin manager

[packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'theblob42/drex.nvim',
  requires = 'kyazdani42/nvim-web-devicons', -- optional
}
```

[vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'theblob42/drex.nvim'
Plug 'kyazdani42/nvim-web-devicons' " optional
```

You only need to install [nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons) if you like to have nice file type icons. The plugin works fine without it.

## Usage

Open a DREX buffer in the current working directory

```
:Drex
```

You can also provide a target path

```
:Drex ~/projects
```

To open the parent directory of the current file

```
:Drex %:h
```

> Check the manual for `cmdline-special` and `filename-modifiers`

DREX also comes with a simple project drawer functionality

```
:DrexDrawerOpen
```

> See `:help drex-commands` for more available commands

### Default Keybindings

> To see the definition of all default keybindings see the [configuration](#configuration) section

- Use `j` and `k` like in any other VIM buffer to navigate up and down
- `v` is mapped to `V` because there is no need for charwise selection

**Basic navigation**

- `l` expands the current element
  - If it is a directory open its content in a subtree
  - If it is a file open the file in the current window
  > `<Right>` and `<2-LeftMouse>` are alternative keybindings
- `h` collapses the current directories subtree
  - If the element under the cursor is an open directory collapse it
  - Otherwise collapse the parent directory of the element
  > `<Left>` and `<RightMouse>` are alternative keybindings
- `<C-v>` opens a file in a vertical split
- `<C-x>` opens a file in a horizontal split
- `<C-t>` opens a file in a new tab
- `<F5>` reloads the current directory (dependent on the cursor position)
- `<C-h>` opens a new DREX buffer in the parent directory of the current root
- `<C-l>` opens the directory under the cursor in a new DREX buffer

**Jumping**

- `gj` jumps to the next sibling
- `gk` jumps to the previous sibling
- `gh` jumps to the parent directory of the current element

**Clipboard**

- `m` marks or unmarks the current element (add or remove it from the clipboard)
- `M` marks the current element (add it to the clipboard)
- `u` unmarks the current element (remove it from the clipboard)
- `cc` clears the clipboard content
- `cs` to show and edit the content of the clipboard

**Actions**

- `s` shows the stats for the current element
- `a` creates a new file or directory
  - to create a new directory end your input with a `/`
  - non-existent parent directories will be created
    (e.g. `foo/bar/file` will create `foo` and `bar` if they don't exist yet)
- `d` deletes the element under the cursor (or the visual selection)
- `D` deletes all elements currently contained in the clipboard
- `p` copies all elements from the clipboard to the path under the cursor
  - this will NOT clear the clipboard, so you can continue to paste elsewhere
- `P` moves all elements from the clipboard to the path under the cursor
- `r` renames the element under the cursor (or the visual selection)
  - this can move the element to another location
  - non-existent parent directories will be created
    (e.g. `foo/bar/file` will create `foo` and `bar` if they don't exist yet)
- `R` to multi rename all elements from the clipboard

**Copy strings**

- `y` copies the name of the element under the cursor
- `Y` copies the relative path of the element under the cursor
- `<C-Y>` copies the absolute path of the element under the cursor

> In visual mode these copy all selected elements (separated by "\n")

## Configuration

There is no initial setup needed to use DREX.  
However you may configure certain settings to your liking.

Check out the default configuration:

```lua
require('drex.config').configure {
    icons = {
        dir_open = "",
        dir_closed = "",
        file_default = "🗎",
    },
    drawer = {
        default_width = 30,
        window_picker = {
            enabled = true,
            labels = 'abcdefghijklmnopqrstuvwxyz',
        },
    },
    disable_default_keybindings = false,
    keybindings = {
        ['n'] = {
            ['v'] = 'V',
            ['l'] = '<cmd>lua require("drex").expand_element()<CR>',
            ['h'] = '<cmd>lua require("drex").collapse_directory()<CR>',
            ['<right>'] = '<cmd>lua require("drex").expand_element()<CR>',
            ['<left>']  = '<cmd>lua require("drex").collapse_directory()<CR>',
            ['<2-LeftMouse>'] = '<LeftMouse><cmd>lua require("drex").expand_element()<CR>',
            ['<RightMouse>']  = '<LeftMouse><cmd>lua require("drex").collapse_directory()<CR>',
            ['<C-v>'] = '<cmd>lua require("drex").open_file("vs")<CR>',
            ['<C-x>'] = '<cmd>lua require("drex").open_file("sp")<CR>',
            ['<C-t>'] = '<cmd>lua require("drex").open_file("tabnew")<CR>',
            ['<C-l>'] = '<cmd>lua require("drex").open_directory()<CR>',
            ['<C-h>'] = '<cmd>lua require("drex").open_parent_directory()<CR>',
            ['<F5>'] = '<cmd>lua require("drex").reload_directory()<CR>',
            ['gj'] = '<cmd>lua require("drex.jump").jump_to_next_sibling()<CR>',
            ['gk'] = '<cmd>lua require("drex.jump").jump_to_prev_sibling()<CR>',
            ['gh'] = '<cmd>lua require("drex.jump").jump_to_parent()<CR>',
            ['s'] = '<cmd>lua require("drex.actions").stats()<CR>',
            ['a'] = '<cmd>lua require("drex.actions").create()<CR>',
            ['d'] = '<cmd>lua require("drex.actions").delete("line")<CR>',
            ['D'] = '<cmd>lua require("drex.actions").delete("clipboard")<CR>',
            ['p'] = '<cmd>lua require("drex.actions").copy_and_paste()<CR>',
            ['P'] = '<cmd>lua require("drex.actions").cut_and_move()<CR>',
            ['r'] = '<cmd>lua require("drex.actions").rename()<CR>',
            ['R'] = '<cmd>lua require("drex.actions").multi_rename("clipboard")<CR>',
            ['M'] = '<cmd>DrexMark<CR>',
            ['u'] = '<cmd>DrexUnmark<CR>',
            ['m'] = '<cmd>DrexToggle<CR>',
            ['cc'] = '<cmd>lua require("drex.actions").clear_clipboard()<CR>',
            ['cs'] = '<cmd>lua require("drex.actions").open_clipboard_window()<CR>',
            ['y'] = '<cmd>lua require("drex.actions").copy_element_name()<CR>',
            ['Y'] = '<cmd>lua require("drex.actions").copy_element_relative_path()<CR>',
            ['<C-y>'] = '<cmd>lua require("drex.actions").copy_element_absolute_path()<CR>',
        },
        ['v'] = {
            ['d'] = ':lua require("drex.actions").delete("visual")<CR>',
            ['r'] = ':lua require("drex.actions").multi_rename("visual")<CR>',
            ['M'] = ':DrexMark<CR>',
            ['u'] = ':DrexUnmark<CR>',
            ['m'] = ':DrexToggle<CR>',
            ['y'] = ':lua require("drex.actions").copy_element_name(true)<CR>',
            ['Y'] = ':lua require("drex.actions").copy_element_relative_path(true)<CR>',
            ['<C-y>'] = ':lua require("drex.actions").copy_element_absolute_path(true)<CR>',
        }
    },
    on_enter = nil,
    on_leave = nil,
}
```

Check out `:help drex-configuration` for more details about the individual options

## Internals

Like [vim-dirvish](https://github.com/justinmk/vim-dirvish) every line is just a file path hidden via `conceal` (plus indentation and an icon). For file system scanning, file interactions (add, delete, rename, etc.) and monitoring DREX uses [libuv](https://github.com/libuv/libuv) which is exposed via `vim.loop`

See also `:help drex-customization` and the [Wiki](https://github.com/TheBlob42/drex.nvim/wiki) for more information and examples

## Credit

- [nvim-tree](https://github.com/kyazdani42/nvim-tree.lua)
- [vim-dirvish](https://github.com/justinmk/vim-dirvish)
- [fern](https://github.com/lambdalisue/fern.vim) 
