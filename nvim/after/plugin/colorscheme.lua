vim.pack.add({
  'https://github.com/catppuccin/nvim',
  'https://github.com/f-person/auto-dark-mode.nvim',
})

require('catppuccin').setup()
require('auto-dark-mode').setup({
  set_dark_mode = function()
    vim.schedule(function()
      vim.opt.background = 'dark'
      vim.cmd('colorscheme catppuccin-macchiato')
    end)
  end,
  set_light_mode = function()
    vim.schedule(function()
      vim.opt.background = 'light'
      vim.cmd('colorscheme catppuccin-latte')
    end)
  end,
})
