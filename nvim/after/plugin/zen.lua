-- Zen mode via snacks.nvim (only zen module enabled)
Config.later(function()
  vim.pack.add({ 'https://github.com/folke/snacks.nvim' })
  require('snacks').setup({
    zen = {
      enabled = true,
      on_open = function()
        vim.b.minicompletion_disable = true
      end,
      on_close = function()
        vim.b.minicompletion_disable = false
      end,
    },
  })
  vim.keymap.set('n', '<Leader>z', function() Snacks.zen() end, { desc = 'Zen mode (toggle)' })
end)
