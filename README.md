## sessionizer.nvim
Tmux-like sessionizer for Neovim 0.12+
> Note: This is a WIP plugin


## Installation
#### Using [Lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "its-saanvi/sessionizer.nvim"
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
}
```

## Configuration
The default options are shown below:
```lua
require("sessionizer").setup({
  keymaps = {
    -- Keybind to open telescope's fuzzy finder with your list of projects (calls :connect).
    finder = "<leader><S-F>",
    -- Keybind to detach from an existing session (calls :detach).
    detach = "<leader>d"
  },
  -- List of directories to source your projects from. Eg: ~/dev, ~/work, etc.
  project_sources = {},
  -- Each project runs as a separate nvim server whose pipe is stored in this directory
  session_dir = "/tmp",
  -- Pre and Post-Hooks for the :connect and :detach actions
  -- All these hooks can be a callback function with no parameters and returning nil
  hooks = {
      -- Run this hook before calling :connect on an existing or new session.
      pre_connect_hook = nil,
      -- Run this hook after calling :connect on an existing or new session.
      post_connect_hook = nil,
      -- Run this hook before calling :detach from the current session.
      pre_detach_hook = nil,
      -- Run this hook after calling :detach from the current session.
      post_detach_hook = nil,
  },
})
```

## Inspiration
[tmux-sessionizer](https://github.com/theprimeagen/tmux-sessionizer)
