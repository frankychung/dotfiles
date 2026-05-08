local wezterm = require("wezterm")

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

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

config.keys = { -- Split pane horizontally (new pane below)
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	-- Split pane vertically (new pane to the right)
	{
		key = "d",
		mods = "CMD|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},

	-- Navigate between panes with hjkl
	{
		key = "h",
		mods = "CMD",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "l",
		mods = "CMD",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
	{
		key = "k",
		mods = "CMD",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "j",
		mods = "CMD",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},

	-- Close current pane
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentPane({ confirm = true }),
	},

	{
		key = "z",
		mods = "CMD",
		action = wezterm.action.TogglePaneZoomState,
	},

	{
		key = "[",
		mods = "CMD",
		action = wezterm.action.ActivateCopyMode,
	},

	-- Rename current tab
	{
		key = ",",
		mods = "CMD",
		action = wezterm.action.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},

	-- Tab navigator
	{
		key = "w",
		mods = "CMD|SHIFT",
		action = wezterm.action.ShowTabNavigator,
	},

	{
		key = "l",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivateLastTab,
	},

	-- Rotate panes clockwise
	{
		key = "r",
		mods = "CMD",
		action = wezterm.action.RotatePanes("Clockwise"),
	},

	-- Rebalance: equalize column widths and per-column row heights
	{
		key = "phys:Equal",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(rebalance_panes),
	},
}

config.font = wezterm.font("PragmataPro")
config.font_size = 12
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true

function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Catppuccin Macchiato"
	else
		return "Catppuccin Latte"
	end
end

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())

config.window_decorations = "RESIZE"
-- config.window_decorations = "RESIZE | MACOS_FORCE_DISABLE_SHADOW"

-- Format tab title to show zoom state and Claude Code instance count
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local title = tab.active_pane.title
	if tab.tab_title and #tab.tab_title > 0 then
		title = tab.tab_title
	end

	-- Add zoom indicator like tmux
	local zoom_indicator = ""
	if tab.active_pane.is_zoomed then
		zoom_indicator = "[Z]"
	end

	-- Count Claude Code instances across all panes in this tab
	local claude_count = 0
	for _, p in ipairs(tab.panes) do
		if p.title:find("Claude Code") or p.title:find("^✳") then
			claude_count = claude_count + 1
		end
	end
	local claude_indicator = ""
	if claude_count > 0 then
		claude_indicator = "󰚩"
	end

	-- Recreate default behavior: tab index + title with padding
	local index = tab.tab_index + 1 -- tab_index is 0-based, display as 1-based
	return string.format(" %d: %s%s%s ", index, title, zoom_indicator, claude_indicator)
end)

return config
