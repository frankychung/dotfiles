# Neovim Config Instructions

## After any change

- Update `CUSTOMIZATIONS.md` whenever adding, removing, or modifying anything in `after/`.
- Keep customizations in `after/` — do not edit files in `plugin/` or `init.lua`.

## Config structure

- Base config is MiniMax (see `MINIMAX.md` for reference).
- All customizations go in `after/plugin/` (overrides) or `after/lsp/` (LSP configs).
- Plugins are installed with `vim.pack.add({ 'url', ... })` — pass a list of URL strings, not tables with keys.
- This config uses nvim 0.12+'s built-in `vim.pack` — not lazy.nvim.

## Adding language support

Adding a new language typically requires up to three things:

1. **Treesitter parser** — add the language to the `languages` table in `after/plugin/treesitter.lua`. Code must be inside the `Config.now_if_args()` wrapper (nvim-treesitter isn't available at top level in after/).
2. **LSP server** — create `after/lsp/<server>.lua` returning a config table (can be `return {}`), then add the server name to the `vim.lsp.enable()` call in `after/plugin/lsp.lua`.
3. **External tools** — LSP servers and formatters must be installed on the system (typically via `brew`). Note what needs installing in `CUSTOMIZATIONS.md`.

## After a MiniMax update

The MiniMax setup script (`nvim -l ./MiniMax/setup.lua`) overwrites files in `plugin/`, `init.lua`, and the demo files in `after/`. It backs up replaced files to `MiniMax-backup/`.

- All customizations live in `after/` — safe from updates.

## Old config

- Previous LazyVim config is backed up at `nvim.bak/` in this dotfiles repo.
- Old customizations summary is in `nvim.bak/CUSTOMIZATIONS.md`.
