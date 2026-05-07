local wezterm = require("wezterm")

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

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

	-- Rebalance two-column pane layout
	{
		key = "phys:Equal",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(rebalance_columns),
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

	-- Count caffeinate instances across all panes in this tab
	local caffeinate_count = 0
	for _, p in ipairs(tab.panes) do
		if p.title:match("^%S+: caffeinate") or p.title == "caffeinate" then
			caffeinate_count = caffeinate_count + 1
		end
	end
	local caffeinate_indicator = ""
	if caffeinate_count > 0 then
		caffeinate_indicator = "󰅶"
	end

	-- Build indicators with space between them if both present
	local indicators = ""
	if claude_indicator ~= "" and caffeinate_indicator ~= "" then
		indicators = claude_indicator .. " " .. caffeinate_indicator
	else
		indicators = claude_indicator .. caffeinate_indicator
	end

	-- Recreate default behavior: tab index + title with padding
	local index = tab.tab_index + 1 -- tab_index is 0-based, display as 1-based
	return string.format(" %d: %s%s%s ", index, title, zoom_indicator, indicators)
end)

return config
