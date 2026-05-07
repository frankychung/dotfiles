# Wezterm Rebalance-Columns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `CMD+SHIFT+=` keybinding to `wezterm.lua` that equalizes the widths of two column positions in the active tab and no-ops on any other layout.

**Architecture:** A single local Lua function `rebalance_columns(window, pane)` placed inline in `wezterm.lua`, registered via `wezterm.action_callback` as a new entry in `config.keys`. The function reads `tab:panes_with_info()`, detects the column layout from distinct `left` values, and dispatches a single `AdjustPaneSize` action on the active pane to move the inter-column boundary. No new files, no module extraction, no tests beyond manual verification (the function depends entirely on the wezterm runtime API, which has no offline harness in this repo).

**Tech Stack:** Wezterm Lua config API (`wezterm.action`, `wezterm.action_callback`, `tab:panes_with_info()`, `window:perform_action`).

**Spec:** `docs/superpowers/specs/2026-05-07-wezterm-rebalance-columns-design.md`

---

## File Structure

Only one file is touched:

- **Modify:** `/Users/franky/dev/dotfiles/wezterm.lua`
  - Add a local function `rebalance_columns` between the commented-out leader line (current line 9) and the `config.keys = { ... }` table assignment (current line 11). The function must be declared before `config.keys` because Lua evaluates the table contents at parse time and the keybinding entry references the function.
  - Add one new entry to the `config.keys` table for the `CMD+SHIFT+=` binding.

No new files. No tests file (wezterm config is not unit-testable in this repo).

---

## Task 1: Add the `rebalance_columns` helper function

**Files:**
- Modify: `/Users/franky/dev/dotfiles/wezterm.lua` — insert function after line 9 (the commented-out leader line), before line 11 (`config.keys = { ...`).

- [ ] **Step 1: Insert the function definition**

Open `/Users/franky/dev/dotfiles/wezterm.lua` and insert the following block on a new line directly after the existing commented-out leader line (`-- config.leader = ...`) and before the `config.keys = {` assignment. Preserve the file's tab indentation style (tabs, not spaces) inside the function body.

```lua
-- Equalize the widths of two-column layouts in the active tab.
-- No-op when the tab has 1 column or 3+ columns, or when a pane is zoomed.
local function rebalance_columns(window, pane)
	local tab = window:active_tab()
	if not tab then
		return
	end

	local panes = tab:panes_with_info()

	-- Skip while a pane is zoomed; AdjustPaneSize is meaningless under zoom
	for _, p in ipairs(panes) do
		if p.is_active and p.is_zoomed then
			return
		end
	end

	-- Collect distinct column positions (unique `left` values)
	local seen = {}
	local lefts = {}
	for _, p in ipairs(panes) do
		if not seen[p.left] then
			seen[p.left] = true
			table.insert(lefts, p.left)
		end
	end

	if #lefts ~= 2 then
		return
	end

	table.sort(lefts)
	local left_col, right_col = lefts[1], lefts[2]

	-- Within a column, all panes share the same width; pick any representative
	local left_w, right_w
	for _, p in ipairs(panes) do
		if p.left == left_col and not left_w then
			left_w = p.width
		elseif p.left == right_col and not right_w then
			right_w = p.width
		end
	end

	local target = math.floor((left_w + right_w) / 2)
	local delta = target - left_w
	if delta == 0 then
		return
	end

	-- Find the active pane's column
	local active_left
	for _, p in ipairs(panes) do
		if p.is_active then
			active_left = p.left
			break
		end
	end

	local action
	if active_left == left_col then
		-- Active in left column: push its right edge
		if delta > 0 then
			action = wezterm.action.AdjustPaneSize({ "Right", delta })
		else
			action = wezterm.action.AdjustPaneSize({ "Left", -delta })
		end
	else
		-- Active in right column: push its left edge
		if delta > 0 then
			action = wezterm.action.AdjustPaneSize({ "Left", delta })
		else
			action = wezterm.action.AdjustPaneSize({ "Right", -delta })
		end
	end

	window:perform_action(action, pane)
end
```

- [ ] **Step 2: Verify the file still parses**

Wezterm auto-reloads on save (default behavior). To check the file parses without launching the GUI, run:

```bash
luac -p /Users/franky/dev/dotfiles/wezterm.lua
```

Expected: no output, exit code 0. If you don't have `luac` installed, you can also run:

```bash
lua -e 'loadfile("/Users/franky/dev/dotfiles/wezterm.lua")() ; print("ok")' 2>&1 | head -5
```

This will fail at runtime because `wezterm` isn't available outside wezterm itself, but a *parse error* (mismatched `end`, etc.) will surface as a syntax error before runtime; a runtime-only failure (like `attempt to index nil 'wezterm'`) means parsing succeeded.

The cheapest sanity check: just look at the file in your editor — modern Lua syntax highlighting will flag a missing `end`. Do not proceed if there are syntax errors.

---

## Task 2: Register the keybinding

**Files:**
- Modify: `/Users/franky/dev/dotfiles/wezterm.lua` — add a new entry to the `config.keys` table.

- [ ] **Step 1: Add the keybinding entry**

Inside the `config.keys = { ... }` table (the block starting around line 11), add the following entry. A good location is right after the `RotatePanes` block (currently around lines 92–97) and before the closing `}` of the table. Preserve tab indentation.

```lua
		-- Rebalance two-column pane layout
		{
			key = "=",
			mods = "CMD|SHIFT",
			action = wezterm.action_callback(rebalance_columns),
		},
```

- [ ] **Step 2: Save the file**

Save `wezterm.lua`. Wezterm has `automatically_reload_config = true` by default, so any open wezterm window will reload the config on save. If a config error occurs, wezterm shows it as a notification overlay rather than crashing — read the notification carefully if reload fails.

---

## Task 3: Manually verify the happy path (two columns, uneven widths)

This task is verification only — no code changes. Each check is a falsifiable observation, not a vibe.

- [ ] **Step 1: Set up an uneven two-column layout**

In any wezterm tab:
1. Start with a single pane.
2. Press `CMD+SHIFT+D` (your existing `SplitVertical` binding) to create two side-by-side panes.
3. Enter the resize key table (or use the mouse if easier) and drag the boundary so the two columns are clearly uneven — e.g., left column ~25% width, right column ~75% width.

- [ ] **Step 2: Press the new binding from the LEFT pane**

Click into the left pane to make it active. Press `CMD+SHIFT+=`.

Expected: the boundary moves so the two columns are within ~1 cell of equal width.

If the boundary moves the **wrong direction** (e.g., left column shrinks further instead of growing toward equal), the `AdjustPaneSize` direction semantics are inverted from what the spec assumed. To fix: in `wezterm.lua` inside `rebalance_columns`, swap `"Right"` ↔ `"Left"` in all four branches inside the `if active_left == left_col then ... else ... end` block. Save and re-test.

- [ ] **Step 3: Press the binding from the RIGHT pane**

Reset to an uneven layout (steps from Step 1). This time click into the right pane. Press `CMD+SHIFT+=`.

Expected: same outcome — columns equalize within ~1 cell. If left-pane test passed but right-pane test fails or moves the wrong way, the bug is isolated to the `else` branch (active in right column) — re-check just those two `AdjustPaneSize` calls.

- [ ] **Step 4: Verify it works with vertical subdivisions inside a column**

Set up: two columns, then inside the right column press `CMD+D` (your existing `SplitHorizontal` — splits horizontally, creating top/bottom in that column). You now have one pane on the left and two stacked panes on the right.

Drag the column boundary to make the layout uneven. Press `CMD+SHIFT+=`.

Expected: the column boundary equalizes (left column width ≈ right column width). The horizontal split inside the right column is unaffected — the top/bottom split ratio inside the right column does not change.

---

## Task 4: Manually verify the no-op cases

- [ ] **Step 1: Single pane**

Open a tab with just one pane (no splits). Press `CMD+SHIFT+=`.

Expected: nothing visible happens. No error notification.

- [ ] **Step 2: Three columns**

Set up: split vertically twice to get three side-by-side panes (`CMD+SHIFT+D`, then `CMD+SHIFT+D` again from one of the resulting panes). Press `CMD+SHIFT+=`.

Expected: no change to any pane's width. No error.

- [ ] **Step 3: Already-balanced two columns**

Two panes side-by-side, already at equal width. Press `CMD+SHIFT+=`.

Expected: no visible change (delta is 0, function returns early). No error.

- [ ] **Step 4: Zoomed pane**

Two-column layout, uneven widths. Press `CMD+Z` (your existing `TogglePaneZoomState`) to zoom one of the panes. With the zoom active, press `CMD+SHIFT+=`.

Expected: nothing happens — the zoom remains, the underlying layout is untouched. Press `CMD+Z` again to unzoom and confirm the columns are still in their original uneven state (i.e., the binding really did no-op rather than silently rebalancing under the zoom).

---

## Task 5: Commit

- [ ] **Step 1: Stage and commit only the wezterm.lua change**

The repo has unrelated unstaged changes (nvim config, macos `.bak` renames). Stage `wezterm.lua` explicitly so nothing else gets pulled in.

```bash
cd /Users/franky/dev/dotfiles
git add wezterm.lua
git status --short
```

Expected: `git status --short` shows `M  wezterm.lua` in the staged section, with all the other modified/untracked files still unstaged.

- [ ] **Step 2: Create the commit**

```bash
git commit -m "$(cat <<'EOF'
add wezterm: CMD+SHIFT+= rebalances two-column pane layouts

Equalizes widths when the active tab has exactly two column positions;
no-ops on any other layout (1 pane, 3+ columns, zoomed, already equal).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds, `git log --oneline -1` shows the new commit.

- [ ] **Step 3: Confirm the commit is clean**

```bash
git show --stat HEAD
```

Expected: exactly one file changed (`wezterm.lua`), with insertions matching the function body + keybinding entry (~85 lines added) and no deletions beyond minor whitespace.
