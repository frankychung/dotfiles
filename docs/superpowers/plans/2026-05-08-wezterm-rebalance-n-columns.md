# Wezterm Rebalance N-Column Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lift the `#lefts == 2` gate on column rebalancing in `rebalance_panes` so `CMD+SHIFT+=` works for any number of columns in left-leaning column trees.

**Architecture:** Replace the "plan every step up front, execute through `call_after`" structure with a "one step per tick, re-read pane info each tick" loop. Each tick reads `tab:panes_with_info()` afresh, finds the leftmost imbalanced column (or row inside a column), and queues a single `pane:activate()` + `AdjustPaneSize` step. The fix targets `segments[i]` (the LEFT pane of boundary i) for every boundary, since `AdjustPaneSize` operates on the active pane's immediate parent split — and in a left-leaning tree, col_i is always the left child of its parent split.

**Tech Stack:** Lua, WezTerm config API (`wezterm.action`, `wezterm.action_callback`, `wezterm.time.call_after`, `MuxTab:panes_with_info`, `MuxPane:activate`).

---

## Spec reference

`docs/superpowers/specs/2026-05-08-wezterm-rebalance-n-columns-design.md`

## Testing approach

Wezterm config has no automated test framework — verification is manual smoke testing in a running wezterm instance. Each task that changes behavior includes manual smoke-test steps with explicit expected results, plus a syntax check via `wezterm --config-file <path> ls` (which exits non-zero on Lua parse errors without launching the GUI).

## Files

- Modify: `wezterm.lua` lines 9–146 (helper + main function)
  - The helper `plan_equalize_axis` becomes `plan_one_step` — same axis-equalize math, but returns the first corrective step (or nil) from a fresh segment snapshot, instead of appending all corrective steps.
  - `rebalance_panes` keeps its setup (zoom check, captured `original_index`) but replaces the single-snapshot grouping + plan-array + step-through-array structure with a `tick(remaining)` loop that re-reads `panes_with_info()` per tick.

## File structure (after change)

`wezterm.lua` keeps its current shape: one helper, one main function, then config keybindings. No new files. The helper and main function remain colocated because they only make sense together.

---

## Task 1: Replace helper and rewrite `rebalance_panes` to step-driven loop

**Files:**
- Modify: `wezterm.lua` lines 9–146

This task replaces both the helper (`plan_equalize_axis` → `plan_one_step`) and the body of `rebalance_panes`. They have to change together — the new main function calls the new helper signature, and intermediate states won't load. So we make the change in a single edit, then validate.

- [ ] **Step 1: Read current state of wezterm.lua**

Run: `wc -l /Users/franky/dev/dotfiles/wezterm.lua` — confirm it's 295 lines (header + functions + keybindings + theme/tab-title hooks). Then read lines 9–146 to confirm the function bodies match what's documented in this plan.

If line counts have drifted, adjust the Edit's `old_string` to match exactly what's currently there.

- [ ] **Step 2: Replace the helper and main function with the new versions**

Use a single `Edit` call on `wezterm.lua`. The `old_string` is the full text from the start of the helper comment block (line 9) through the end of `rebalance_panes` (line 146 — the closing `end` followed by a blank line). The `new_string` is:

```lua
-- Find the first imbalanced segment along an axis and return one corrective
-- {target, action} step (or nil if all segments are within 1 cell of target).
--
-- segments: array of N { pane, pos, size } entries, sorted along the axis.
-- grow_dir / shrink_dir: AdjustPaneSize directions for grow / shrink along the
--   axis (columns: "Right" / "Left"; rows: "Down" / "Up").
--
-- We always act on segments[i] (the LEFT/TOP pane of boundary i). In a
-- left-leaning split tree, segments[i] is the left child of the split that
-- defines boundary i, so AdjustPaneSize on it moves that split. delta > 0
-- means segments[i] is too small -- grow it (boundary moves forward); delta
-- < 0 means it's too big -- shrink it (boundary moves backward).
--
-- Each step changes segments[i]'s size and redistributes the difference among
-- segments[i+1..n] in a way wezterm controls internally. Callers handle that
-- by re-reading pane info before the next step rather than predicting the
-- redistribution.
local function plan_one_step(segments, grow_dir, shrink_dir)
	local n = #segments
	if n < 2 then
		return nil
	end

	local total = 0
	for _, s in ipairs(segments) do
		total = total + s.size
	end
	local target = math.floor(total / n)

	for i = 1, n - 1 do
		local delta = target - segments[i].size
		if math.abs(delta) >= 1 then
			local action
			if delta > 0 then
				action = wezterm.action.AdjustPaneSize({ grow_dir, delta })
			else
				action = wezterm.action.AdjustPaneSize({ shrink_dir, -delta })
			end
			return { target = segments[i].pane, action = action }
		end
	end

	return nil
end

-- Equalize column widths and per-column row heights in the active tab.
-- No-op when the active pane is zoomed.
--
-- AdjustPaneSize operates on the active pane's immediate parent split, not on
-- whichever boundary the caller intends. In a left-leaning split tree (the
-- common topology produced by "split right from the new pane" or "split down
-- from the new pane"), segments[i] is always the left child of the split that
-- defines boundary i, so acting on segments[i] moves the right boundary --
-- which is what we want. This breaks for right-leaning or mixed trees; we
-- accept that limitation.
--
-- Acting on segments[i] resizes segments[i] AND every segment to its right
-- (the rest of the split's right subtree) by the same total amount, with
-- internal redistribution we don't model. So we can't pre-plan a sequence of
-- steps from one snapshot -- the cached sizes for segments[i+1..n] go stale
-- after each step. Instead, we re-read panes_with_info() each tick, find the
-- next imbalance, queue one activate+resize, wait 50 ms for the action queue
-- to drain, and tick again. A max-iteration guard prevents runaway loops.
local function rebalance_panes(window, focused_pane)
	local tab = window:active_tab()
	if not tab then
		return
	end

	local original_index
	for _, p in ipairs(tab:panes_with_info()) do
		if p.is_active and p.is_zoomed then
			return
		end
		if p.is_active then
			original_index = p.index
		end
	end

	-- Compute the next corrective step from a fresh snapshot, or nil if
	-- everything is balanced. Column pass first; row pass per column after.
	local function compute_next_step()
		local panes = tab:panes_with_info()

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
			table.sort(columns_by_left[left], function(a, b)
				return a.top < b.top
			end)
		end

		if #lefts >= 2 then
			local col_segments = {}
			for _, left in ipairs(lefts) do
				local rep = columns_by_left[left][1]
				table.insert(col_segments, { pane = rep.pane, pos = rep.left, size = rep.width })
			end
			local step = plan_one_step(col_segments, "Right", "Left")
			if step then
				return step
			end
		end

		for _, left in ipairs(lefts) do
			local col = columns_by_left[left]
			if #col >= 2 then
				local row_segments = {}
				for _, p in ipairs(col) do
					table.insert(row_segments, { pane = p.pane, pos = p.top, size = p.height })
				end
				local step = plan_one_step(row_segments, "Down", "Up")
				if step then
					return step
				end
			end
		end

		return nil
	end

	-- Bound iterations defensively. For an N x M grid we expect at most
	-- (N - 1) + N * (M - 1) steps; 50 covers up to ~5x5 with slack for
	-- one-off corrective ticks.
	local function tick(remaining)
		if remaining <= 0 then
			return
		end
		local step = compute_next_step()
		if not step then
			if original_index then
				window:perform_action(wezterm.action.ActivatePaneByIndex(original_index), focused_pane)
			end
			return
		end
		step.target:activate()
		window:perform_action(step.action, focused_pane)
		wezterm.time.call_after(0.05, function()
			tick(remaining - 1)
		end)
	end

	tick(50)
end
```

The `old_string` for this Edit must start at the beginning of line 9 (the comment `-- Plan an equalize-along-axis pass...`) and end after the closing `end` of `rebalance_panes` on line 146 (include the trailing newline; do not include the blank line that follows). If you're unsure, Read the file first and copy the exact span.

- [ ] **Step 3: Syntax-check the new file**

Run: `wezterm --config-file /Users/franky/dev/dotfiles/wezterm.lua ls`

Expected output: a list of running wezterm windows/tabs (or `no panes` if no instance is running). Either way, it must exit 0. Any Lua parse error appears on stderr with a line number — fix it before continuing.

If `wezterm` is not on PATH, try the full path: `/Applications/WezTerm.app/Contents/MacOS/wezterm --config-file /Users/franky/dev/dotfiles/wezterm.lua ls`.

- [ ] **Step 4: Reload wezterm config**

The user must do this — you can't reload another process's config from this session. Tell the user:

> "Open wezterm and either restart it or hit `CMD+SHIFT+R` to reload the config. Then come back."

Wait for confirmation before proceeding to manual tests.

- [ ] **Step 5: Manual smoke test — 3-column layout**

Tell the user to:

1. Open a fresh wezterm tab.
2. Press `CMD+SHIFT+D` to split right (now 2 columns).
3. Press `CMD+SHIFT+D` again from the new pane to split right (now 3 columns, left-leaning tree).
4. Imbalance the columns: focus the leftmost pane (`CMD+H` until you're in col1), then use `CMD+SHIFT+ArrowRight` repeatedly (if that's bound) — or simply drag the column dividers with the mouse — until widths are roughly 50/25/25.
5. Press `CMD+SHIFT+=`.

Expected: the three columns end up roughly equal width (within 1–2 cells of each other). Exact widths depend on terminal width; for a 200-cell-wide tab, expect ~66/66/68 or ~66/67/67.

If the inner column squishes again, the bug is back — stop and re-examine. Report state to the user before proceeding.

- [ ] **Step 6: Manual smoke test — 4-column layout**

Tell the user:

1. From the current 3-column tab, focus the rightmost pane and `CMD+SHIFT+D` once more (now 4 columns).
2. Imbalance manually so widths are skewed.
3. Press `CMD+SHIFT+=`.

Expected: 4 columns roughly equal width.

- [ ] **Step 7: Manual smoke test — 2-column regression**

Tell the user:

1. New tab. `CMD+SHIFT+D` once. Imbalance. `CMD+SHIFT+=`.

Expected: two columns roughly equal width. (This was the only working case before.)

- [ ] **Step 8: Manual smoke test — single column / zoomed pane no-ops**

Tell the user:

1. New tab with one pane. `CMD+SHIFT+=`. Expected: nothing happens (no error in wezterm log, no resize).
2. New tab. `CMD+SHIFT+D` once. Press `CMD+Z` to zoom one pane. `CMD+SHIFT+=`. Expected: nothing happens (zoomed pane stays zoomed at full size).

- [ ] **Step 9: Manual smoke test — rows in columns**

Tell the user:

1. New tab. `CMD+SHIFT+D` (now 2 cols).
2. Focus the right column, `CMD+D` (split horizontal — split down within the right column, now 3 panes: col1 spanning full height, col2-top, col2-bot).
3. `CMD+D` again from col2-bot to make col2-bot-bot — now col2 has 3 rows.
4. Imbalance the rows in col2 (drag the horizontal divider).
5. Press `CMD+SHIFT+=`.

Expected: col1 and col2 are roughly equal width AND col2's three rows are roughly equal height. This exercises the row pass with 3+ rows in a left-leaning row tree, which the spec calls out as previously broken (latent bug, same root cause as columns).

- [ ] **Step 10: Commit**

Run from `/Users/franky/dev/dotfiles`:

```bash
git add wezterm.lua
git commit -m "$(cat <<'EOF'
generalize wezterm rebalance_panes to N columns via step-driven re-read

Lift the 2-column gate by switching the algorithm from
"plan-every-step-up-front from one snapshot" to "compute one corrective
step from a fresh panes_with_info() each tick." Always act on
segments[i] (the left/top pane of boundary i) instead of alternating
between segments[i] and segments[i+1] based on delta sign, since
AdjustPaneSize operates on the active pane's immediate parent split,
not on whichever boundary we semantically intend -- and in a
left-leaning tree, segments[i] is always the left child of the split
that defines boundary i.

Re-reading per tick avoids the stale-cache problem when acting on an
inner column: each step changes segments[i] AND redistributes the
difference among segments[i+1..n] in a way wezterm controls internally.

Same fix applies to the row pass for 3+ rows in a left-leaning row
tree, which had the same latent bug as columns.

Spec: docs/superpowers/specs/2026-05-08-wezterm-rebalance-n-columns-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review checklist

**Spec coverage:**
- ✅ Lift `#lefts == 2` gate → Task 1 Step 2 (no `if #lefts == 2` in new code; column pass runs whenever `#lefts >= 2`).
- ✅ Always act on `segments[i]` → Task 1 Step 2, `plan_one_step` always returns `segments[i].pane`.
- ✅ Re-read pane info between steps → Task 1 Step 2, `compute_next_step` calls `tab:panes_with_info()` afresh each tick.
- ✅ Apply same fix to row pass → Task 1 Step 2, row pass uses the same `plan_one_step` helper.
- ✅ Topology assumption documented in code comment → Task 1 Step 2, comment on `rebalance_panes`.
- ✅ Skip if active pane zoomed → Task 1 Step 2, preserved from existing code.
- ✅ Restore original focus → Task 1 Step 2, `original_index` capture and `ActivatePaneByIndex` restore preserved.
- ✅ 50 ms `call_after` between steps → Task 1 Step 2, `wezterm.time.call_after(0.05, ...)` in tick.
- ✅ Acceptance: 3-col, 4-col, 2-col regression, zoomed no-op, rows-in-columns → Task 1 Steps 5–9.

**Type / signature consistency:**
- ✅ `plan_one_step(segments, grow_dir, shrink_dir)` returns `{target, action}` table or nil; both call sites (column pass, row pass) handle the nil case identically.
- ✅ `step.target` is a MuxPane (from `p.pane`), `step.action` is a wezterm.action — same types as before.
- ✅ `original_index` capture and `ActivatePaneByIndex` restore unchanged from current code.

**Placeholders:** None.

**Out-of-scope items handled:** Topology detection, alternative resize APIs, delay tuning — all noted in spec, not in the plan.
