# Custom LazyVim Config Summary

Backup taken 2026-04-10. Base: LazyVim with nvim 0.11.4 (upgraded to 0.12.0 during debugging).

## LazyVim Extras Enabled (lazyvim.json)

| Category | Extra |
|----------|-------|
| Coding | mini-surround, yanky |
| Editor | mini-files |
| Lang | docker, dotnet, json, markdown, sql, toml, typescript, yaml |
| Test | core (neotest) |
| UI | mini-hipatterns |

## Config files (lua/config/)

All default — no customizations in options.lua, keymaps.lua, or autocmds.lua.

## Plugin customizations (lua/plugins/)

### colorscheme.lua
- **auto-dark-mode.nvim** — auto-switches between catppuccin-macchiato (dark) and catppuccin-latte (light) based on macOS appearance

### conform.lua
- Adds **prettier** as HTML formatter

### noice.lua
- Originally: skipped LSP progress messages
- **Modified during debugging**: disabled entirely (`enabled = false`) due to crashes on nvim 0.12.0

### snacks.lua
- **Zen mode** config: disables git signs, diagnostics, inlay hints; toggles blink completion off/on when entering/leaving zen

### fsharp.lua
- **fsautocomplete** LSP with `--background-service-enabled`
- Treesitter `fsharp` parser
- **neotest-vstest** adapter for .NET testing

### rescript.lua
- **vim-rescript** for syntax/filetype support
- **rescriptls** LSP
- Treesitter `rescript` parser

### example.lua
- Inactive — returns `{}` immediately (LazyVim starter template, untouched)
