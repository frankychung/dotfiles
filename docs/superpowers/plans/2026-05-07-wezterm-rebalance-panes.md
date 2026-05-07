# Wezterm Rebalance-Panes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing 2-column-only `rebalance_columns` function in `wezterm.lua` with a generalized `rebalance_panes` that equalizes column widths (any N) in Pass 1, then equalizes row heights within each column (any M) in Pass 2. Keybinding stays at `CMD+SHIFT+=`.

**Architecture:** Single helper `equalize_along_axis` does the per-axis work using `wezterm.action.AdjustPaneSize` against representative panes. `rebalance_panes` calls it once across columns, then once per column across rows. Cached `panes_with_info()` is reused across both passes — width changes don't affect `top`/`height`, and the `pos + size` invariant on the moving axis means earlier boundary moves don't invalidate later boundary calculations.

**Tech Stack:** Lua, WezTerm config API (`window:perform_action`, `tab:panes_with_info`, `wezterm.action.AdjustPaneSize`).

**Note on testing:** WezTerm config runs inside the WezTerm process; there is no Lua test harness in this repo, and the action API requires a live `Window`/`Pane`. Verification is manual by exercising layout scenarios in a running WezTerm session. The plan provides a syntax check and a tight manual verification matrix.

---

## File Structure

- **Modify:** `/Users/franky/dev/dotfiles/wezterm.lua` (lines 9–70 replaced; line ~164 keybinding callback name updated)

No new files. The whole change is contained to `wezterm.lua`.

Spec reference: `docs/superpowers/specs/2026-05-07-wezterm-rebalance-panes-design.md`.

---

### Task 1: Replace `rebalance_columns` with `equalize_along_axis` + `rebalance_panes`

**Files:**
- Modify: `/Users/franky/dev/dotfiles/wezterm.lua:9-70` (function block)
- Modify: `/Users/franky/dev/dotfiles/wezterm.lua:160-165` (keybinding entry; callback name and comment)

- [ ] **Step 1: Replace the `rebalance_columns` function block with the helper + new function**

Use Edit with `old_string` matching lines 9–70 exactly:

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

	-- AdjustPaneSize moves the inter-column boundary regardless of which
	-- pane is active: {Right, n} pushes the boundary right (left grows,
	-- right shrinks); {Left, n} pushes it left (left shrinks, right grows).
	local action
	if delta > 0 then
		action = wezterm.action.AdjustPaneSize({ "Right", delta })
	else
		action = wezterm.action.AdjustPaneSize({ "Left", -delta })
	end

	window:perform_action(action, pane)
end
```

Replace with `new_string`:

```lua
-- Equalize sizes of N adjacent segments along one axis.
--
-- segments: array of N { pane, pos, size } entries, sorted along the axis.
--   pane is the representative pane used to drive AdjustPaneSize for that segment.
--   pos is the segment's leading-edge coordinate (left for cols, top for rows).
--   size is the segment's extent along the axis (width for cols, height for rows).
-- grow_dir / shrink_dir: AdjustPaneSize directions that grow / shrink segment i.
--   columns: "Right" / "Left"     rows: "Down" / "Up"
--
-- Correctness note: each AdjustPaneSize on boundary i changes segment i and i+1
-- by equal-and-opposite amounts, leaving every other segment's `pos + size`
-- invariant. So we can compute each boundary's current position from the
-- cached `pos + size` of the segment to its left, even after earlier moves.
local function equalize_along_axis(window, segments, grow_dir, shrink_dir)
	local n = #segments
	if n < 2 then
		return
	end

	local total = 0
	for _, s in ipairs(segments) do
		total = total + s.size
	end
	local target = math.floor(total / n)
	local origin = segments[1].pos

	for i = 1, n - 1 do
		local target_boundary = origin + i * target
		local current_boundary = segments[i].pos + segments[i].size
		local delta = target_boundary - current_boundary
		if delta ~= 0 then
			local action
			if delta > 0 then
				action = wezterm.action.AdjustPaneSize({ grow_dir, delta })
			else
				action = wezterm.action.AdjustPaneSize({ shrink_dir, -delta })
			end
			window:perform_action(action, segments[i].pane)
		end
	end
end

-- Equalize column widths and per-column row heights in the active tab.
-- No-op when the active pane is zoomed.
local function rebalance_panes(window, _pane)
	local tab = window:active_tab()
	if not tab then
		return
	end

	local panes = tab:panes_with_info()

	for _, p in ipairs(panes) do
		if p.is_active and p.is_zoomed then
			return
		end
	end

	-- Group panes by column (`left`), keeping a sorted list of distinct lefts.
	local columns_by_left = {}
	local lefts = {}
	for _, p in ipairs(panes) do
		if not columns_by_left[p.left] then
			columns_by_left[p.left] = {}
			table.insert(lefts, p.left)
		end
		table.insert(columns_by_left[p.left], p)
	end
	table.sort(lefts)
	for _, left in ipairs(lefts) do
		table.sort(columns_by_left[left], function(a, b) return a.top < b.top end)
	end

	-- Pass 1: equalize column widths. Representative pane per column is its
	-- first row (any pane in the column would do; width is shared).
	if #lefts >= 2 then
		local col_segments = {}
		for _, left in ipairs(lefts) do
			local rep = columns_by_left[left][1]
			table.insert(col_segments, { pane = rep, pos = rep.left, size = rep.width })
		end
		equalize_along_axis(window, col_segments, "Right", "Left")
	end

	-- Pass 2: equalize row heights within each column. Cached top/height are
	-- still valid here -- width changes from Pass 1 do not affect them.
	for _, left in ipairs(lefts) do
		local col = columns_by_left[left]
		if #col >= 2 then
			local row_segments = {}
			for _, p in ipairs(col) do
				table.insert(row_segments, { pane = p, pos = p.top, size = p.height })
			end
			equalize_along_axis(window, row_segments, "Down", "Up")
		end
	end
end
```

- [ ] **Step 2: Update the keybinding to call `rebalance_panes`**

In the `config.keys` table around line 160, find this entry:

```lua
		-- Rebalance two-column pane layout
		{
			key = "phys:Equal",
			mods = "CMD|SHIFT",
			action = wezterm.action_callback(rebalance_columns),
		},
```

Replace it with:

```lua
		-- Rebalance: equalize column widths and per-column row heights
		{
			key = "phys:Equal",
			mods = "CMD|SHIFT",
			action = wezterm.action_callback(rebalance_panes),
		},
```

- [ ] **Step 3: Lua syntax check**

Run: `luac -p /Users/franky/dev/dotfiles/wezterm.lua`
Expected: no output, exit code 0.

If `luac` is not installed, run `lua -e 'loadfile("/Users/franky/dev/dotfiles/wezterm.lua")'` instead. Either confirms the file parses.

(WezTerm uses its own bundled Lua, so a passing parse here does not guarantee API correctness — that's what manual verification covers — but it catches typos cheaply.)

- [ ] **Step 4: Reload WezTerm config**

In a running WezTerm window, press `CTRL+SHIFT+R` (default WezTerm reload) or quit and relaunch WezTerm. Open the debug overlay (`CTRL+SHIFT+L` by default) and confirm there are no Lua errors after reload.

If the debug overlay shows an error, fix it before continuing. Common causes: typo in a direction string (`"Up"` / `"Down"` / `"Left"` / `"Right"`), missing comma, missing `end`.

- [ ] **Step 5: Commit**

```bash
git add /Users/franky/dev/dotfiles/wezterm.lua
git commit -m "$(cat <<'EOF'
generalize wezterm rebalance to N columns and per-column rows

Replaces rebalance_columns (two-column-only width equalization) with
rebalance_panes, which equalizes widths across any number of columns
and then equalizes row heights inside each column. Same keybinding
(CMD+SHIFT+=). Helper equalize_along_axis is reused for both passes.

Spec: docs/superpowers/specs/2026-05-07-wezterm-rebalance-panes-design.md
EOF
)"
```

---

### Task 2: Manual verification matrix

**Files:** none (interactive testing in WezTerm)

For each scenario, set up the layout described, press `CMD+SHIFT+=`, and confirm the expected result. Skip a scenario only if it's structurally impossible to set up. Stop on first failure and report.

- [ ] **Scenario A — Regression: two columns, single row each**

Setup: open a fresh WezTerm tab. Press `CMD+SHIFT+D` to vertical-split (new pane to the right). Manually drag the divider so column widths are clearly uneven (e.g., 80/20).

Action: press `CMD+SHIFT+=`.

Expected: the two columns become equal width (within 1 cell). This is the original behavior; if it breaks, regression.

- [ ] **Scenario B — Three or more columns**

Setup: in a fresh tab, vertical-split twice with `CMD+SHIFT+D` to get 3 columns. Drag dividers so columns are uneven (e.g., 60/30/10).

Action: press `CMD+SHIFT+=`.

Expected: all three columns become equal width (within 1–2 cells, last column may absorb remainder).

- [ ] **Scenario C — Single column, multiple rows**

Setup: fresh tab. Press `CMD+D` (horizontal split, new pane below) twice to get 3 stacked panes in one column. Drag horizontal dividers to make heights uneven.

Action: press `CMD+SHIFT+=`.

Expected: all three rows become equal height (within 1–2 cells). Column width is unchanged (only one column).

- [ ] **Scenario D — Two columns, one with multiple rows**

Setup: fresh tab. `CMD+SHIFT+D` to make two columns. Activate the left column, then `CMD+D` twice to give it 3 rows. Make column widths uneven and the left column's row heights uneven.

Action: press `CMD+SHIFT+=`.

Expected: column widths equalize, AND the left column's three rows equalize in height. Right column (single pane) stays full-height.

- [ ] **Scenario E — Both columns have multiple rows**

Setup: extending Scenario D, also split the right column with `CMD+D` so it has 2 rows. Make all four pane sizes visibly uneven.

Action: press `CMD+SHIFT+=`.

Expected: column widths equalize. Left column's rows equalize among themselves. Right column's rows equalize among themselves. The two columns' row boundaries do not need to align with each other.

- [ ] **Scenario F — Already balanced (idempotency)**

Setup: any of the prior scenarios immediately AFTER it has been balanced.

Action: press `CMD+SHIFT+=` a second time.

Expected: no visible change, no flicker. (All deltas should be 0 and the function returns without issuing any `AdjustPaneSize`.)

- [ ] **Scenario G — Zoomed pane**

Setup: any multi-pane layout. Press `CMD+Z` to zoom the active pane.

Action: press `CMD+SHIFT+=`.

Expected: nothing happens (silent no-op). Press `CMD+Z` again to unzoom — layout is unchanged from before zooming.

- [ ] **If any scenario fails, diagnose and fix**

Most likely failure modes and fixes:

1. **Row directions inverted** (rows shrink when they should grow, or vice versa): swap the `"Down"` and `"Up"` arguments in the Pass 2 call to `equalize_along_axis`.
2. **Column directions inverted**: swap `"Right"` and `"Left"` in the Pass 1 call. (Unlikely — these match the original tested implementation.)
3. **`AdjustPaneSize` ignores the explicit pane parameter** and only ever affects the active pane: row balancing in non-focused columns won't work. Mitigation: before each `window:perform_action`, additionally call `window:perform_action(wezterm.action.ActivatePane, segments[i].pane)`. Note this changes user focus — verify whether WezTerm's API really requires it before adding.

After fixing, re-run the failing scenario and re-commit.

- [ ] **Final commit (only if Step 8 fixes were needed)**

```bash
git add /Users/franky/dev/dotfiles/wezterm.lua
git commit -m "fix wezterm rebalance_panes: <one-line description of fix>"
```

If verification passed without fixes, skip this step.

---

## Self-Review

**Spec coverage:**
- Pass 1 (N-column width balance) → Task 1 Step 1 (lines under "Pass 1: equalize column widths")
- Pass 2 (per-column row height balance) → Task 1 Step 1 (lines under "Pass 2: equalize row heights within each column")
- Zoom no-op → Task 1 Step 1 (`is_zoomed` check at top of `rebalance_panes`); Task 2 Scenario G
- 1-column edge case → `if #lefts >= 2` guard around Pass 1; Task 2 Scenario C
- 1-pane-per-column edge case → `if #col >= 2` guard around each Pass 2 call; covered implicitly by Scenario A (right column in B/D)
- Already-balanced → `delta ~= 0` check inside `equalize_along_axis`; Task 2 Scenario F
- Off-by-one rounding (last segment absorbs remainder) → `target = floor(total/n)` plus the way `target_boundary = origin + i*target` is only used for boundaries 1..n-1, so the last segment naturally takes whatever's left. Acceptable per spec.
- Cross-column shared row boundaries → covered by spec's reasoning; algorithm does not need special-casing. Scenario E exercises both-column row balancing without requiring boundary alignment.
- Keybinding stays at `CMD+SHIFT+=` → Task 1 Step 2.
- Single-file change in `wezterm.lua` → matches "Implementation location" in spec.

**Placeholder scan:** No TBDs, no "fill in", no "similar to Task N", no missing code blocks. Each step has the actual edit content or the actual command.

**Type/name consistency:** `equalize_along_axis(window, segments, grow_dir, shrink_dir)` is defined once and called twice with consistent argument order. `rebalance_panes` matches the keybinding registration. Function name change `rebalance_columns` → `rebalance_panes` is reflected in both definition and registration.

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-07-wezterm-rebalance-panes.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
