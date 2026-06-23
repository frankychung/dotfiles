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

-- Per-pane Claude Code state, persisting across GUI events. Maintained by the
-- update-status handler further down; read by the "jump to attention tab"
-- keybinding and the tab-title formatter. claude_state[pane_id] = { status, attention }.
local claude_state = {}

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

	-- Send a real Escape for Ctrl+[ so it works under the kitty keyboard
	-- protocol (e.g. exiting insert mode in Claude Code) without tmux in between
	{
		key = "[",
		mods = "CTRL",
		action = wezterm.action.SendKey({ key = "Escape" }),
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

	-- Last active tab.
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

	-- Force a full repaint. Works around WebGpu's lazy re-render (wezterm #3384),
	-- where the grid goes stale until a resize/focus event. A font-size nudge
	-- triggers the same layout + re-raster pass a manual resize does, then
	-- reverts -- visually net-zero.
	{
		key = "r",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			window:perform_action(wezterm.action.IncreaseFontSize, pane)
			wezterm.time.call_after(0.03, function()
				window:perform_action(wezterm.action.DecreaseFontSize, pane)
			end)
		end),
	},

	-- Rebalance: equalize column widths and per-column row heights
	{
		key = "phys:Equal",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(rebalance_panes),
	},

	-- Toggle dark<->light across every window. Reads the focused window's
	-- current scheme and flips all windows to the other one. (macOS only sends
	-- the appearance-change event to the focused window, so a manual toggle is
	-- the reliable way to flip every window at once.)
	{
		key = "t",
		mods = "CTRL|CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local dark, light = "Catppuccin Macchiato", "Catppuccin Latte"
			local current = window:effective_config().color_scheme
			local next_scheme = current == light and dark or light
			for _, w in ipairs(wezterm.gui.gui_windows()) do
				w:set_config_overrides({ color_scheme = next_scheme })
			end
		end),
	},

	-- Fuzzy selector over every pane across all windows/tabs. The fuzzy filter
	-- matches the whole label, so tab title / process / cwd are all searchable.
	{
		key = "p",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local choices = {}
			for _, w in ipairs(wezterm.mux.all_windows()) do
				for _, t in ipairs(w:tabs()) do
					local ttitle = t:get_title()
					for _, p in ipairs(t:panes()) do
						local cwd = p:get_current_working_dir()
						cwd = type(cwd) == "string" and cwd or (cwd and cwd.file_path) or ""
						local proc = (p:get_foreground_process_name() or ""):gsub(".*/", "")
						table.insert(choices, {
							id = tostring(p:pane_id()),
							label = ttitle .. "  ·  " .. proc .. "  " .. cwd,
						})
					end
				end
			end

			window:perform_action(
				wezterm.action.InputSelector({
					title = "Panes",
					fuzzy = true,
					choices = choices,
					action = wezterm.action_callback(function(win, p, id)
						if not id then
							return
						end
						local target = wezterm.mux.get_pane(tonumber(id))
						if target then
							target:activate() -- focus pane + its containing tab
						end
					end),
				}),
				pane
			)
		end),
	},

	-- Jump to the first tab (left to right) with a Claude pane needing attention.
	{
		key = "]",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			for _, info in ipairs(window:mux_window():tabs_with_info()) do
				for _, p in ipairs(info.tab:panes()) do
					local st = claude_state[p:pane_id()]
					if st and st.attention then
						window:perform_action(wezterm.action.ActivateTab(info.index), pane)
						return
					end
				end
			end
		end),
	},
}

config.font = wezterm.font("PragmataPro")
config.font_size = 12
config.front_end = "WebGpu" -- Metal on Apple Silicon; testing if it avoids long-session render slowdowns
config.max_fps = 120 -- default 60; lowers keystroke-to-present latency (esp. on 120Hz displays)
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false

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

-- Classify a pane title into a Claude status, or nil if it isn't a Claude pane.
-- Working: Claude animates a braille spinner (U+2800-U+28FF) at the start of its
-- OSC title -- in UTF-8 that's byte1 == 0xE2 (226) and byte2 in 0xA0..0xA3
-- (160..163). Idle/ready: title leads with ✳ (U+2733) or contains "Claude Code".
-- Working is checked first: a leading spinner means working regardless of rest.
local function claude_status_from_title(title)
	if not title or title == "" then
		return nil
	end
	local b1, b2 = title:byte(1, 2)
	if b1 == 226 and b2 and b2 >= 160 and b2 <= 163 then
		return "working"
	end
	if title:find("^✳") or title:find("Claude Code") then
		return "idle"
	end
	return nil
end

-- Maintain the Claude attention bookkeeping once per status tick. Walk every
-- pane, detect Working->Idle transitions (the spinner stopping == finished OR
-- waiting for input -- the same signal from the title's view), clear the flag on
-- the focused pane (the "I looked at it" rule), and prune closed panes.
wezterm.on("update-status", function(window, pane)
	local focused_id = pane and pane:pane_id() or nil
	local seen = {}
	local should_ding = false

	for _, w in ipairs(wezterm.mux.all_windows()) do
		for _, t in ipairs(w:tabs()) do
			for _, p in ipairs(t:panes()) do
				local status = claude_status_from_title(p:get_title())
				if status then
					local id = p:pane_id()
					seen[id] = true
					local prev = claude_state[id]
					if not prev then
						-- First sighting: seed without a transition so a freshly
						-- spawned pane doesn't flag attention as it settles.
						claude_state[id] = { status = status, attention = false }
					else
						if status == "working" then
							prev.attention = false
						elseif prev.status == "working" then
							prev.attention = true
							if id ~= focused_id then
								should_ding = true
							end
						end
						prev.status = status
					end
				end
			end
		end
	end

	if focused_id and claude_state[focused_id] then
		claude_state[focused_id].attention = false
	end

	for id in pairs(claude_state) do
		if not seen[id] then
			claude_state[id] = nil
		end
	end

	-- Chime once when an unfocused pane stops working (finished or now waiting).
	if should_ding then
		wezterm.background_child_process({ "afplay", "/System/Library/Sounds/Ping.aiff" })
	end
end)

-- Format tab title: tab index + title, a tmux-style zoom indicator, and a
-- color-coded Claude indicator (robot glyph + pane count). Working/idle is read
-- live from pane titles; attention comes from the cached state above. Color
-- follows the most urgent state: attention (red) > working (yellow) > idle (dim).
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local title = tab.active_pane.title
	if tab.tab_title and #tab.tab_title > 0 then
		title = tab.tab_title
	end

	local zoom_indicator = ""
	if tab.active_pane.is_zoomed then
		zoom_indicator = "[Z]"
	end

	local claude_count, has_working, has_attention = 0, false, false
	for _, p in ipairs(tab.panes) do
		local status = claude_status_from_title(p.title)
		if status then
			claude_count = claude_count + 1
			if status == "working" then
				has_working = true
			end
			local st = claude_state[p.pane_id]
			if st and st.attention then
				has_attention = true
			end
		end
	end

	local index = tab.tab_index + 1 -- tab_index is 0-based, display as 1-based
	local items = { { Text = string.format(" %d: %s%s", index, title, zoom_indicator) } }

	if claude_count > 0 then
		-- Catppuccin blue/yellow/green, per the active light/dark scheme.
		local dark = config.color_scheme == "Catppuccin Macchiato"
		local color
		if has_attention then
			color = dark and "#8aadf4" or "#1e66f5"
		elseif has_working then
			color = dark and "#eed49f" or "#df8e1d"
		else
			color = dark and "#a6da95" or "#40a02b"
		end
		table.insert(items, { Foreground = { Color = color } })
		table.insert(items, { Text = "󰚩 " .. claude_count })
		table.insert(items, "ResetAttributes")
	end

	table.insert(items, { Text = " " })
	return wezterm.format(items)
end)

return config
