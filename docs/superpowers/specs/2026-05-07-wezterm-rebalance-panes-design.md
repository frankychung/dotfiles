# Wezterm Rebalance-Panes Keybinding

## Goal

Generalize the existing `CMD+SHIFT+=` keybinding from "equalize widths of two columns" to a full two-axis tidy of the active tab:

1. **Pass 1 — Columns:** equalize widths of all distinct column positions (any N).
2. **Pass 2 — Rows:** for each column, equalize heights of the panes in that column.

Replaces the existing `rebalance_columns` function with `rebalance_panes`. The keybinding stays at `CMD+SHIFT+=`.

This supersedes the prior spec at `2026-05-07-wezterm-rebalance-columns-design.md`, which intentionally limited scope to two columns and explicitly excluded row balancing.

## Definitions

- A *column* is a distinct horizontal position (`left` value) occupied by one or more panes in the active tab.
- A *row within column C* is a pane whose `left == C`, ordered by `top` ascending.
- Within a column, every pane shares the same `width`. Within a row group of a column, every pane has its own `height` and `top`.

## Algorithm

The operation reduces to one primitive applied twice on different axes.

### Primitive: equalize-along-axis

Given a sorted list of N adjacent segments along an axis with positions `p_i` and sizes `s_i` and shared total `S = Σ s_i`:

1. Target size `T = floor(S / N)`. The last segment absorbs `S - (N-1) * T` so totals match exactly. Off-by-one cell asymmetry on the last segment is acceptable.
2. For boundary `i` in `1 .. N-1`:
   - `target_i = p_1 + i * T`
   - `current_i = p_i + s_i` (unaffected by earlier boundary moves on this axis, since each move only changes the size of the two segments adjacent to that boundary)
   - `delta_i = target_i - current_i`
   - If `delta_i == 0`, skip.
   - Else, issue one `AdjustPaneSize` on a representative pane of segment `i`:
     - **Horizontal axis (columns):** `{"Right", delta_i}` if positive, `{"Left", -delta_i}` if negative.
     - **Vertical axis (rows):** `{"Down", delta_i}` if positive, `{"Up", -delta_i}` if negative.

`window:perform_action(action, target_pane)` lets us drive this for any pane, not just the focused one.

### Top-level flow

```
1. tab = window:active_tab(); panes = tab:panes_with_info()
2. If the active pane is zoomed, return.
3. Build columns map: { left -> { panes sorted by top ascending } }.
4. Pass 1 (columns): if there are >= 2 columns, equalize column widths.
   For boundary i, the representative pane for column i is any pane in that column
   (e.g., its first row).
5. Pass 2 (rows): for each column with >= 2 rows, equalize row heights.
   For boundary i within a column, the representative pane is the i-th row of that column.
```

No re-fetch between passes — width changes do not affect `top` or `height`, and the cached `top`/`height` values remain authoritative for Pass 2.

## Edge cases

- **1 column:** Pass 1 is a no-op (no boundaries). Pass 2 still runs.
- **1 pane in a column:** that column's row pass is a no-op.
- **Already balanced:** every `delta_i == 0`, so silent no-op.
- **Zoomed pane:** silent no-op via `is_zoomed` check on the active pane.
- **Cross-column shared row boundaries:** if two columns happen to share a horizontal boundary, rebalancing the first column may pull the shared boundary into place for the second column too. By the time the second column's row pass runs, its computed deltas are non-zero only if its own row sizes still differ — which is fine; the move either re-positions the shared boundary (idempotent if already correct) or adjusts an unshared portion. No special-casing required.
- **Off-by-one rounding:** the last segment on each axis absorbs the remainder. Asymmetry at most `N-1` cells across the tab. Acceptable per user direction ("some pixel off is fine").

## Implementation location

Single function `rebalance_panes` in `wezterm.lua`, replacing the current `rebalance_columns`. Wired to the existing keybinding:

```lua
{ key = "phys:Equal", mods = "CMD|SHIFT", action = wezterm.action_callback(rebalance_panes) }
```

Estimated size: 50–70 lines including the shared `equalize_along_axis` helper. No new files, no module extraction.

## Known risks

- `AdjustPaneSize` direction semantics for `Down`/`Up` mirror the assumed semantics for `Right`/`Left` already validated by the original implementation. If `Down`/`Up` happen to be inverted relative to expectation, all four sign branches in the row pass flip. Verification: a one-shot manual test with a column of three unevenly-sized panes.
- `window:perform_action(action, pane)` driving `AdjustPaneSize` on a non-active pane is the documented contract; if a WezTerm version interprets it as targeting only the active pane, the row pass would mis-target boundaries. Mitigation: manual test post-implementation, fall back to activating each pane temporarily if needed.

## Out of scope

- Multi-tab balancing (still only the active tab).
- Reflowing non-aligned splits or the binary split tree itself.
- Undo, animation, or progressive feedback.
- Per-axis keybindings (one shortcut, both axes).
