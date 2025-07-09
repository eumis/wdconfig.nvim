# wdconfig.nvim

Loads lua config for current working directory.

## Installation

- neovim required
- install using your favorite plugin manager

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "eumis/wdconfig.nvim", 
    dependencies = { "nvim-lua/plenary.nvim" }
}
```

[mini.deps](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-deps.md)

```lua
add({
    source = "eumis/wdconfig.nvim",
    depends = { "nvim-lua/plenary.nvim" },
})
```

[packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "eumis/wdconfig.nvim",
    requires = { {"nvim-lua/plenary.nvim"} }
}
```

## Usage

```lua
local wdconfig = require "wdconfig"

-- Load current working directory config
wdconfig.load_cwd() -- cwd should be trusted to be loaded

-- Trust current working directory config
wdconfig.trust(vim.fn.getcwd())

-- Load config
wdconfig.load("~/.local/pc_specific_config.lua") -- doesn't need to be trusted

-- Add lua package to path
wdconfig.load_package("lua", vim.fn.getcwd())
```

```vim
:WdcLoad
:WdcLoad ~/.local/pc_specific_config.lua
:WdcTrust
:WdcTrust /some/path
```

## Config

```lua
-- default values
require "wdconfig".setup {
    config_name = "config.lua", -- config file name, can be a list - first existing will be used
    trusted_cwd_only = true -- load_cwd() will load config only if cwd is trusted
}
```
