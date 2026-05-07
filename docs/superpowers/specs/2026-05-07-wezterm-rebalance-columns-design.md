# Wezterm Rebalance-Columns Keybinding

## Goal

Add a `CMD+SHIFT+=` keybinding to `wezterm.lua` that equalizes the widths of two column positions in the active tab. No-op when the tab has one column or three+ columns.

## Definition of "columns"

A *column* is a distinct horizontal position (`left` value) occupied by one or more panes in the active tab. A column may itself contain vertical subdivisions (top/bottom rows). The rebalance fires only when the tab has exactly two distinct column positions, regardless of subdivisions inside either column.

## Algorithm

The keybinding runs a `wezterm.action_callback`:

1. Call `tab:panes_with_info()` on the active tab. Each entry has `left`, `top`, `width`, `height`, `is_active`, `is_zoomed`.
2. If the active pane is zoomed, return — `AdjustPaneSize` is meaningless under zoom.
3. Collect the set of distinct `left` values across all panes. If the set size is not exactly 2, return.
4. Within a column, every pane shares the same `width`, so pick any one pane per column to read `left_w` and `right_w`.
5. Compute `target = floor((left_w + right_w) / 2)` and `delta = target - left_w`. If `delta == 0`, return.
6. Determine which column the active pane is in (compare its `left` to the smaller of the two collected `left` values).
7. Issue a single `AdjustPaneSize` on the active pane to move the inter-column boundary by `|delta|` cells:
   - Active in **left** column → push its right edge: `{"Right", delta}` if `delta > 0`, else `{"Left", -delta}`.
   - Active in **right** column → push its left edge: `{"Left", delta}` if `delta > 0`, else `{"Right", -delta}`.

Wezterm propagates a column-boundary move to every pane that shares that boundary, so vertical subdivisions inside either column resize correctly without explicit handling.

## Edge cases

- **1 pane / 3+ columns:** silent no-op.
- **Already balanced:** silent no-op via the `delta == 0` check.
- **Zoomed pane:** silent no-op via the `is_zoomed` check.
- **Off-by-one rounding:** acceptable. Cell-unit integer math may leave a 1-cell asymmetry; not worth correcting.

## Implementation location

A local function `rebalance_columns` in `wezterm.lua`, wrapped in `wezterm.action_callback`, registered as a new entry in `config.keys`:

```lua
{ key = "=", mods = "CMD|SHIFT", action = wezterm.action_callback(rebalance_columns) }
```

No new files, no module extraction — the function is ~30 lines and belongs alongside the other keybindings.

## Known risk

`AdjustPaneSize` direction semantics are inferred from community-config convention: `{"Right", n}` grows the active pane's right edge by `n` cells, shrinking its right neighbor. If the actual semantic is inverted, all four sign branches in step 7 flip. Verification is a one-shot manual test after implementation: split a pane vertically with very uneven widths, press the binding, observe.

## Out of scope

- Rebalancing rows (vertical splits within a column).
- Rebalancing more than two columns (e.g., equalizing three columns).
- Per-tab vs per-window scope: only the active tab is touched.
