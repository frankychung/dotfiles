local wezterm = require("wezterm")

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Equalize sizes of N adjacent segments along one axis.
--
-- segments: array of N { pane, pos, size } entries, sorted along the axis.
--   pane is the MuxPane userdata used as the action target for that segment.
--   pos is the segment's leading-edge coordinate (left for cols, top for rows).
--   size is the segment's extent along the axis (width for cols, height for rows).
-- grow_dir / shrink_dir: AdjustPaneSize directions for the forward / backward axis.
--   columns: "Right" / "Left"     rows: "Down" / "Up"
--
-- AdjustPaneSize grows the target pane in the given direction by pushing its neighbor
-- on that side. To move boundary i forward (delta > 0), we grow segment i forward
-- (it has segment i+1 as the forward neighbor). To move it backward (delta < 0), we
-- grow segment i+1 backward (it has segment i as the backward neighbor). Picking the
-- pane that actually has a neighbor in the push direction is essential -- acting on
-- the topmost / leftmost segment with a backward direction is a silent no-op.
--
-- AdjustPaneSize uses the window's *currently active* pane regardless of what we
-- pass to perform_action, so we must ActivatePane each target pane before issuing
-- the resize. The caller is expected to restore the user's original focus afterward.
--
-- Each move changes only segments i and i+1 by equal-and-opposite amounts, leaving
-- every other segment's `pos + size` invariant, so cached values from a single
-- panes_with_info() call remain valid for all subsequent boundaries on this axis.
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
			local action, target_pane
			if delta > 0 then
				action = wezterm.action.AdjustPaneSize({ grow_dir, delta })
				target_pane = segments[i].pane
			else
				action = wezterm.action.AdjustPaneSize({ shrink_dir, -delta })
				target_pane = segments[i + 1].pane
			end
			target_pane:activate()
			window:perform_action(action, target_pane)
		end
	end
end

-- Equalize column widths and per-column row heights in the active tab.
-- No-op when the active pane is zoomed.
local function rebalance_panes(window, focused_pane)
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
		table.sort(columns_by_left[left], function(a, b)
			return a.top < b.top
		end)
	end

	-- Pass 1: equalize column widths. Representative pane per column is its
	-- first row (any pane in the column would do; width is shared).
	if #lefts >= 2 then
		local col_segments = {}
		for _, left in ipairs(lefts) do
			local rep = columns_by_left[left][1]
			table.insert(col_segments, { pane = rep.pane, pos = rep.left, size = rep.width })
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
				table.insert(row_segments, { pane = p.pane, pos = p.top, size = p.height })
			end
			equalize_along_axis(window, row_segments, "Down", "Up")
		end
	end

	-- Restore the user's original focus (equalize_along_axis activated panes
	-- as it went so AdjustPaneSize would target each one in turn).
	if focused_pane then
		focused_pane:activate()
	end
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
