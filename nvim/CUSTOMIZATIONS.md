# Customizations

Changes on top of the MiniMax base config. All customizations live in `after/` to keep the base untouched.

## Colorscheme — `after/plugin/colorscheme.lua`

Replaces the default `miniwinter` theme with **catppuccin** and **auto-dark-mode.nvim**:

- Dark mode: `catppuccin-macchiato`
- Light mode: `catppuccin-latte`
- Switches automatically based on macOS appearance setting

## Markdown — `after/plugin/markdown.lua`

- **render-markdown.nvim** — in-buffer rendering of headings, code blocks, tables, checkboxes, etc.

## LSP — `after/plugin/lsp.lua` + `after/lsp/`

- **marksman** — Markdown LSP (go-to-definition for links/headings, completions)
- **fsautocomplete** — F# LSP (requires `dotnet tool install -g fsautocomplete`)
- Semantic tokens disabled as workaround for nvim 0.12 CPU bug (neovim/neovim#36257) — remove once fixed upstream

## Treesitter — `after/plugin/treesitter.lua`

Additional treesitter languages beyond the MiniMax defaults:

- `fsharp`
- `rescript`
- `javascript`, `typescript`, `tsx`, `jsdoc`

## F# — `after/plugin/treesitter.lua` + `after/lsp/fsautocomplete.lua`

- Treesitter `fsharp` parser
- fsautocomplete LSP server (requires `dotnet tool install -g fsautocomplete`)

## ReScript — `after/plugin/treesitter.lua` + `after/lsp/rescriptls.lua`

- Treesitter `rescript` parser
- rescriptls LSP server (ships with `@rescript/core` — no separate install needed)

## JavaScript/TypeScript — `after/plugin/treesitter.lua` + `after/lsp/ts_ls.lua`

- Treesitter `javascript`, `typescript`, `tsx`, `jsdoc` parsers
- ts_ls LSP server with `checkJs` enabled for type checking in plain .js files
- Uses the TypeScript bundled with the project (no global install needed)
