local wezterm = require("wezterm")

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Equalize the widths of two-column layouts in the active tab.
-- No-op when the tab has 1 column or 3+ columns, or when a pane is zoomed.
--
-- AdjustPaneSize uses the window's currently active pane regardless of what's
-- passed to perform_action. To make this work in all four (focused-column, delta-sign)
-- combinations, the column that needs to grow is activated first; restoring the
-- user's original focus afterward is queued as a follow-up action.
local function rebalance_panes(window, focused_pane)
	local tab = window:active_tab()
	if not tab then
		return
	end

	local panes = tab:panes_with_info()

	local original_index
	for _, p in ipairs(panes) do
		if p.is_active and p.is_zoomed then
			return
		end
		if p.is_active then
			original_index = p.index
		end
	end

	-- Collect distinct column positions (unique `left` values).
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

	-- Within a column, every pane shares width; pick any pane in each column as
	-- the activation target for that column.
	local left_w, right_w
	local left_pane, right_pane
	for _, p in ipairs(panes) do
		if p.left == left_col and not left_w then
			left_w = p.width
			left_pane = p.pane
		elseif p.left == right_col and not right_w then
			right_w = p.width
			right_pane = p.pane
		end
	end

	local target = math.floor((left_w + right_w) / 2)
	local delta = target - left_w
	if delta == 0 then
		return
	end

	-- delta > 0: left column needs to grow. Activate any left-column pane and
	-- push the inter-column boundary right.
	-- delta < 0: right column needs to grow. Activate a right-column pane and
	-- push the boundary left.
	local target_pane, action
	if delta > 0 then
		target_pane = left_pane
		action = wezterm.action.AdjustPaneSize({ "Right", delta })
	else
		target_pane = right_pane
		action = wezterm.action.AdjustPaneSize({ "Left", -delta })
	end

	target_pane:activate()
	window:perform_action(action, focused_pane)

	-- Restore focus after the resize processes (queued to run after the resize).
	if original_index then
		window:perform_action(wezterm.action.ActivatePaneByIndex(original_index), focused_pane)
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
