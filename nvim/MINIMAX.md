# MiniMax Config Reference

Base config from [nvim-mini/MiniMax](https://github.com/nvim-mini/MiniMax), copied into this dotfiles repo.

## Installed Plugins (non-mini)

| Plugin | Purpose |
|--------|---------|
| nvim-treesitter | Language parsers for syntax highlighting, textobjects, indent |
| nvim-treesitter-textobjects | Treesitter-based textobjects |
| nvim-lspconfig | LSP server configurations |
| conform.nvim | Code formatting (LSP fallback) |
| friendly-snippets | Large collection of snippet files |

## Mini.nvim Modules (30 active)

### UI / Startup

- **mini.basics** — sensible defaults (window nav with `Ctrl+hjkl`, clipboard with `gy`/`gp`, toggle options with `\`)
- **mini.icons** — file/LSP icons
- **mini.notify** — notification popups (`<Leader>en` for history)
- **mini.starter** — start screen / dashboard
- **mini.statusline** — status line
- **mini.tabline** — buffer/tab line
- **mini.map** — minimap sidebar (`<Leader>mt` to toggle)
- **mini.indentscope** — animated indent guide for current scope

### Editing

- **mini.ai** — extended textobjects (function args, brackets, quotes, etc.)
- **mini.align** — align text (`ga` in visual)
- **mini.comment** — toggle comments (`gcc`)
- **mini.completion** — autocompletion with LSP + snippet support
- **mini.move** — move lines/selections with `Alt+hjkl`
- **mini.operators** — replace (`gr`), exchange (`gx`), sort (`gs`), multiply (`gm`)
- **mini.pairs** — auto-close brackets/quotes
- **mini.splitjoin** — toggle single-line/multi-line (`gS`)
- **mini.surround** — add/delete/change surroundings (`sa`, `sd`, `sr`)
- **mini.snippets** — snippet engine (with friendly-snippets)
- **mini.trailspace** — highlight/trim trailing whitespace

### Navigation

- **mini.pick** — fuzzy finder (`<Leader>ff` files, `<Leader>fg` grep, `<Leader>fh` help)
- **mini.files** — file explorer (`<Leader>ed`)
- **mini.jump** — enhanced `f`/`t` motions
- **mini.jump2d** — 2D jumping (like hop/leap)
- **mini.bracketed** — `[`/`]` navigation (buffers, diagnostics, etc.)
- **mini.visits** — track/pick visited files (`<Leader>fv`)
- **mini.clue** — key binding hints (like which-key)
- **mini.cmdline** — enhanced command line UI
- **mini.keymap** — multi-key combo mappings

### Git

- **mini.git** — git commands and `<Leader>gs` show at cursor
- **mini.diff** — inline diff signs, overlay toggle (`<Leader>go`)

### Other

- **mini.sessions** — session save/restore (`<Leader>sn`, `<Leader>sr`)
- **mini.extra** — extra pickers and textobjects
- **mini.misc** — utility helpers (zoom, resize)
- **mini.hipatterns** — highlight patterns (hex colors, TODO/FIXME/etc.)
- **mini.bufremove** — delete buffers without closing windows

## Leader Key Groups (`<Space>` + ...)

| Key | Group | Examples |
|-----|-------|---------|
| `b` | Buffer | `bs` scratch, `bd` delete, `ba` alternate |
| `e` | Explore/Edit | `ed` directory, `ef` file dir, `ei` init.lua |
| `f` | Find (fuzzy) | `ff` files, `fg` grep, `fh` help, `fb` buffers |
| `g` | Git | `gc` commit, `gd` diff, `gl` log, `go` overlay |
| `l` | Language/LSP | `la` actions, `ld` diagnostic, `lr` rename, `ls` definition |
| `m` | Map | `mt` toggle, `mf` focus |
| `o` | Other | `oz` zoom, `ot` trim whitespace |
| `s` | Session | `sn` new, `sr` read, `sw` write |
| `t` | Terminal | `tt` vertical, `tT` horizontal |
| `v` | Visits | `vv` add core label, `fv` pick visited |

## Common Workflows

### LSP (Language Server Protocol)

**Navigating code:**

| Key | Action |
|-----|--------|
| `<Space>ls` | Go to definition |
| `<Space>lt` | Type definition |
| `<Space>li` | Implementation |
| `<Space>lR` | References — list all usages |
| `<Space>lh` | Hover — show docs/type info |
| `<C-o>` | Jump back after navigating |

**Editing:**

| Key | Action |
|-----|--------|
| `<Space>lr` | Rename symbol across project |
| `<Space>la` | Code actions (quick fixes, refactors) |
| `<Space>lf` | Format file (conform.nvim, LSP fallback) |

**Diagnostics:**

| Key | Action |
|-----|--------|
| `<Space>ld` | Show full error at cursor |
| `<Space>fd` | Fuzzy find all workspace diagnostics |
| `<Space>fD` | Fuzzy find buffer diagnostics |
| `[d` / `]d` | Previous/next diagnostic |

**Finding symbols:**

| Key | Action |
|-----|--------|
| `<Space>fs` | Workspace symbols (live search) |
| `<Space>fS` | Document symbols |

**Completion (Insert mode):**

- Start typing — popup after 100ms
- `<Tab>` / `<S-Tab>` — navigate candidates
- `<C-f>` / `<C-b>` — scroll info window
- `<C-e>` — dismiss
- `(` — shows signature help

### Switch buffers

- `[b` / `]b` — previous/next buffer
- `<Space>fb` — fuzzy pick from open buffers
- `<Space>ba` — jump to alternate (last used) buffer

## Config Structure

```
nvim/
├ init.lua              Startup, plugin manager, loading helpers
├ plugin/               Auto-sourced during startup
│ ├ 10_options.lua      Built-in Neovim behavior
│ ├ 20_keymaps.lua      Custom mappings
│ ├ 30_mini.lua         Mini.nvim module configuration
│ └ 40_plugins.lua      Non-mini plugins (treesitter, LSP, conform, snippets)
├ snippets/             User-defined snippets
├ after/                Overrides (loaded after plugin/)
│ ├ plugin/             Custom plugin overrides
│ ├ ftplugin/           Filetype-specific settings
│ ├ lsp/                Language server configurations
│ └ snippets/           Higher priority snippet files
└ nvim-pack-lock.json   Plugin lockfile
```

## Updating

### Plugins

Inside nvim, run:

```
:lua vim.pack.update()
```

Then press `:write` to confirm the lockfile update.

### MiniMax base config

The base config is a snapshot from the MiniMax repo. To check for upstream changes:

```bash
cd /tmp && git clone --filter=blob:none https://github.com/nvim-mini/MiniMax
diff -r /tmp/MiniMax ~/dev/dotfiles/nvim --exclude=.git --exclude=after --exclude=nvim-pack-lock.json
```

Cherry-pick any changes you want. Customizations in `after/` won't conflict.
