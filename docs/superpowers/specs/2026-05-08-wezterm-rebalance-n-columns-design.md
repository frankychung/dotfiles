# Wezterm Rebalance-Panes: N-Column Generalization

## Goal

Lift the `#lefts == 2` gate on the column pass in `rebalance_panes` so that `CMD+SHIFT+=` equalizes column widths for any number of columns (and per-column row heights, as it already does), in left-leaning column trees.

This supersedes the prior N-column attempt described in `2026-05-07-wezterm-rebalance-panes-design.md`, which had the right shape but the wrong target-pane / direction logic and was reverted in commit `3a63715`. Row balancing was later restored in `60c2bab` via a `call_after`-based step machinery; this spec extends that working machinery to the column pass.

## Why the previous attempt failed

`AdjustPaneSize` operates on the active pane's **immediate parent split** in the pane tree, not on whichever column boundary you semantically intend to move.

Building a 3-column layout the natural way ("split right, then split right again from the new pane") produces a left-leaning tree:

```
vsplit(col1, vsplit(col2, col3))
```

In this tree:

- col1 is LEFT of the depth-0 split. Its right edge is boundary 1 (col1/col2).
- col2 is LEFT of the depth-1 split. Its right edge is boundary 2 (col2/col3) — **not** boundary 1.
- col3 is RIGHT of the depth-1 split. Its left edge is boundary 2.

The previous algorithm wanted to move boundary 1 leftward when col1 was too wide, and did so by activating `segments[i+1]` (col2) and applying `{Left, N}`. The mental model was "col2 grows leftward, taking from col1." But col2's immediate parent is the depth-1 split, so `{Left, N}` actually moves boundary 2 leftward — col2 shrinks, col3 grows. Boundary 1 doesn't move.

Trace for `[100, 50, 50]`, target ≈ 66:

- Step 1: activate col2, `{Left, 34}` → col2 shrinks to 16, col3 grows to 84. State `[100, 16, 84]`.
- Step 2: activate col3, `{Left, 18}` → col3 grows leftward, col2 collapses to min. State ≈ `[100, ~1, ~99]`.

That matches the reported "outer columns balanced, inner columns squished" symptom.

The 2-column case happened to work because col2 is RIGHT of the only split, so `{Left, N}` correctly moves col2's left edge (which IS the only boundary).

## Approach

Two changes to the column pass:

### 1. Always act on `segments[i]` for boundary i

In a left-leaning tree, col_i is always the left child of its immediate parent split (the depth-(i-1) split). Acting on col_i with the right direction moves boundary i directly:

- delta > 0: `AdjustPaneSize{Right, delta}` on col_i → col_i grows, boundary moves right.
- delta < 0: `AdjustPaneSize{Left, -delta}` on col_i → col_i shrinks, boundary moves left.

Direction is no longer used to switch which pane to activate — only to switch grow vs shrink.

### 2. Re-read pane info between steps; plan one step at a time

Acting on col_i in a left-leaning tree moves the depth-(i-1) split. That changes col_i AND the entire right subtree (col_(i+1) .. col_N) by the same total amount, distributed internally by wezterm in a way we don't model. The cached `pos+size` invariant the previous algorithm relied on is broken in this topology.

Replace the "plan all up front, then step through" loop with a step-driven loop that re-reads `tab:panes_with_info()` before computing each step's delta. Each step:

1. Read fresh pane info, group by column.
2. If column widths are imbalanced, pick the leftmost column whose width differs from `target` by ≥ 1, plan an action on it, execute, schedule the next tick.
3. Else if any column has imbalanced rows, do the same per-column row pass (one row step per tick).
4. Else, all balanced — restore original focus, done.

The 50 ms `call_after` delay between steps stays. So does the "skip if active pane is zoomed" check.

## Topology assumption

This works only for left-leaning column trees. Right-leaning or mixed trees will fail differently; the symptom would be "different inner column squishes" depending on where the leaning flips.

The natural workflow ("split right from the new pane") produces left-leaning. Other workflows (e.g., always splitting from the leftmost pane) can produce right-leaning. We document the assumption in a comment but don't try to detect or correct topology — wezterm doesn't expose pane-tree topology directly, and topology detection would balloon the scope.

## Row pass

Apply the same change to the row pass for symmetry: act on `segments[i]` (always), use direction to pick grow vs shrink, re-read between steps. The current row pass works for 2 rows per column for the same reason 2-column worked (single split, RIGHT child happens to align with the algorithm's choice). It would have the same bug as columns for 3+ rows in a left-leaning row tree. Folding the fix into both passes keeps the code uniform and pre-empts a future "row balancing breaks for 3+ rows" report.

## Out of scope

- Detecting pane-tree topology and supporting right-leaning / mixed trees.
- Replacing `AdjustPaneSize` with a different mechanism (e.g., a tree-walking resize). Wezterm doesn't expose the pane tree; this would require upstream changes.
- Tuning the 50 ms delay. The current value works for the row pass; we'll keep it.

## Acceptance

- 3-column tab with widths roughly 50/25/25 rebalances to ~33/33/34 on `CMD+SHIFT+=`.
- 4-column tab with one wide column rebalances to ~25/25/25/25.
- 2-column case continues to work (no regression).
- Per-column row balancing continues to work for 2 rows; 3+ rows in a left-leaning row tree now also works.
- No-op when the active pane is zoomed.
- Active pane focus is restored after rebalancing.
