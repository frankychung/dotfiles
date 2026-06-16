vim.pack.add({
  'https://github.com/catppuccin/nvim',
  'https://github.com/f-person/auto-dark-mode.nvim',
})

require('catppuccin').setup()

local function set_dark()
  vim.opt.background = 'dark'
  vim.cmd('colorscheme catppuccin-macchiato')
end

local function set_light()
  vim.opt.background = 'light'
  vim.cmd('colorscheme catppuccin-latte')
end

require('auto-dark-mode').setup({
  set_dark_mode = function()
    vim.schedule(set_dark)
  end,
  set_light_mode = function()
    vim.schedule(set_light)
  end,
})

-- Manual toggle. auto-dark-mode doesn't reliably see macOS appearance changes
-- when nvim runs inside herdr, so flip light/dark by hand. Mirrors the wezterm
-- CTRL+CMD+SHIFT+T toggle (catppuccin-macchiato / catppuccin-latte).
local function toggle_theme()
  if vim.o.background == 'dark' then
    set_light()
  else
    set_dark()
  end
end

vim.api.nvim_create_user_command('ThemeToggle', toggle_theme, { desc = 'Toggle light/dark colorscheme' })
vim.keymap.set('n', '<leader>tt', toggle_theme, { desc = 'Toggle theme (light/dark)' })
