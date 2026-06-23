# WezTerm Claude Code status indicators — design

## Goal

Improve the per-tab Claude Code indicators in `wezterm.lua`. Today the tab title shows a single static robot glyph (`󰚩`) whenever any pane in the tab looks like a Claude Code session. Replace that with a stateful, color-coded indicator that tells you, at a glance, which tabs have a Claude session that is **working**, which have one that **wants your attention** (finished or waiting for input), and which are merely **idle**.

## Background: how herdr detects Claude state

This design borrows the detection approach from [herdr](https://github.com/ogulcancelik/herdr) (`src/detect/manifest.rs`, `src/detect/manifests/claude.toml`, `src/pane/agent_detection.rs`). Herdr is manifest-driven: prioritized rules match text patterns against regions of the terminal and resolve to one of four states — Working, Blocked, Done (finished, unreviewed), Idle (done and seen). Two signal sources matter here:

- **OSC terminal title (cheap, title-only).** Claude Code writes its status into the terminal title. Herdr's highest-priority rules read it: a leading braille spinner glyph (`U+2800–U+28FF` followed by a space) means **Working**; a leading `✳` (`U+2733`) means **Idle**.
- **Visible screen text (richer, needs scrollback).** For **Blocked**, herdr scans the bottom of the visible pane for permission prompts ("do you want to proceed?", numbered yes/no menus, "esc to cancel"). This requires reading screen content, which WezTerm's `format-tab-title` does not expose.

Herdr's **Done vs Idle** distinction is bookkeeping, not a screen signal: a pane that transitions Working→Idle is "Done/attention" until the user views it, then decays to plain Idle.

## Scope decision

We use **title-only detection plus the Done/attention bookkeeping layer**. We deliberately do *not* scan screen text, so we do not get herdr's dedicated Blocked state.

This is a smaller surface than it sounds, because from the title's point of view "finished" and "paused waiting for permission" are the **same event**: the braille spinner stops and the title drops back to `✳`. A Working→Idle transition therefore captures both cases where Claude wants you. That single "attention" signal covers the real need — "which tab should I look at?" — without ever reading scrollback.

## Architecture

A single `update-status` handler is the detection driver; `format-tab-title` is a pure reader of cached state.

`update-status` fires roughly once per second per window and receives the window's active pane as an argument. The handler walks every pane via the mux, reads each title, updates a per-pane state table (detecting Working→Idle transitions), and clears the attention flag on the focused pane it was handed. `format-tab-title` then reads the cached aggregate for the tab being rendered and returns colored format items.

This is preferred over classifying titles inline in `format-tab-title` because `format-tab-title` only runs on redraw — a background tab that finishes while you are elsewhere may not re-render to catch its transition — and because it cannot cleanly identify the globally focused pane, which the attention-clear rule needs. A self-scheduled `wezterm.time.call_after` timer was also considered and rejected: it duplicates what `update-status` already provides and loses the free focused-pane argument.

## Components

### 1. State model & storage

A module-level Lua table, persisting across events in the GUI process:

```
claude_state[pane_id] = { status = "working" | "idle", attention = <bool> }
```

A pane that is not a Claude session has no entry. `status` is the last observed title-derived state. `attention` means "finished or waiting since you last looked."

### 2. Detection: title → status

For each pane, read `pane:get_title()` and classify by leading glyph. Lua patterns are byte-oriented, so the braille check is done on UTF-8 bytes:

- **Working** — title starts with a braille spinner glyph (`U+2800–U+28FF`): first byte `226` (`0xE2`), second byte in `160..163` (`0xA0..0xA3`). Test: `title:byte(1) == 226 and title:byte(2) >= 160 and title:byte(2) <= 163`.
- **Idle (Claude)** — title starts with `✳` (`title:find("^✳")`) or contains `"Claude Code"`. This preserves the current detection signal.
- **Not Claude** — neither matches: no state entry, and any stale entry for that pane_id is pruned.

These patterns are what herdr keys off, but they depend on exactly what Claude Code emits into the OSC title in this environment. **The first implementation step is empirical:** run a Claude pane and dump `pane:get_title()` while it is working versus idle, and confirm the bytes before wiring the classifier. The existing config already proves `✳` appears; the working spinner needs the same confirmation.

### 3. Transition & attention logic

Run inside the `update-status` handler. For each Claude pane, compare the freshly read `status` against the stored one:

- `working → idle` ⇒ set `attention = true` (finished or waiting for input — indistinguishable, and both want you).
- `→ working` ⇒ set `attention = false` (actively running again).
- The pane handed to `update-status` (the focused pane): if it is a Claude pane, clear its `attention`. This implements the "cleared when the Claude pane is focused" rule — a finished pane in a background tab stays flagged until that specific pane is focused.
- Prune `claude_state` entries for pane_ids not seen during the scan (closed panes).

An optional flicker guard (herdr requires the idle reading to persist a few extra ticks before publishing) is intentionally left out of the initial implementation and added only if transient repaints cause the indicator to flip.

### 4. Rendering in `format-tab-title`

Reads cached state for the tab's panes (keyed by `tab.panes[].pane_id`), aggregates, and returns colored format items:

- **Count** — number of Claude panes in the tab.
- **Color** — the highest-priority state present, in order: **attention** (red) > **working** (yellow) > **idle** (dim/grey).
- **Output** — the robot glyph plus the count (e.g. `󰚩2`) in that color, appended after the title alongside the existing `[Z]` zoom indicator.

Because the config runs `use_fancy_tab_bar = false`, the function returns `wezterm.format({ {Foreground=...}, {Text=...}, ... })` rather than a bare string. The tab index, title, and zoom indicator are preserved.

### 5. Edge cases & polish

- **Light/dark themes.** The config toggles Catppuccin Latte/Macchiato. Start with two fixed hues (a warm yellow, a red) that read on both schemes; branch on `window:effective_config().color_scheme` only if a color reads poorly.
- **Startup grace.** A freshly spawned Claude pane should not flag attention on its first idle→working settle. Seed a new pane_id at its first observed status without emitting a transition.
- **Poll cadence.** The default `update-status` interval (~1s) is acceptable. Drop to ~500ms only if Working latency feels slow.

## Out of scope

- Screen-text scanning and a dedicated Blocked state (folded into "attention").
- A global status-bar summary of counts across tabs/workspaces.
- Per-pane state persistence across WezTerm restarts.

## Testing

This is a single-file WezTerm Lua config; verification is manual and empirical:

1. Confirm the working-spinner title bytes by dumping `pane:get_title()` from a live working Claude pane.
2. Verify a working pane shows a yellow indicator; that it flips to red attention on completion; and that focusing the pane clears it to dim idle.
3. Verify a tab with multiple Claude panes shows the correct count and the highest-priority color.
4. Verify the indicator behaves correctly across a light/dark toggle and after closing a Claude pane (entry pruned, no stale indicator).
