local wezterm = require("wezterm")

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
	-- Split pane horizontally (new pane below)
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
		mods = "LEADER",
		action = wezterm.action.ActivateCopyMode,
	},

	-- Rename current tab (similar to tmux leader + ,)
	{
		key = ",",
		mods = "LEADER",
		action = wezterm.action.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},

	-- Find/switch to tab (similar to tmux leader + f)
	{
		key = "f",
		mods = "LEADER",
		action = wezterm.action.ShowTabNavigator,
	},

	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action.ActivateLastTab,
	},
}

config.font = wezterm.font("PragmataPro")
config.font_size = 13
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Catppuccin Macchiato"
	else
		return "Catppuccin Latte"
	end
end

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())

-- Configure local Unix domain for local multiplexing
config.unix_domains = {
	{
		name = "unix",
	},
}

-- Configure SSH domain for remote multiplexing
config.ssh_domains = {
	{
		name = "coursebasedev",
		remote_address = "172.105.204.67",
		username = "franky",
	},
}

-- Auto-connect to local domain on startup
-- This seems to break startup. Whatevs, not needed locally
-- config.default_gui_startup_args = { "connect", "unix" }

config.window_decorations = "RESIZE"

return config
