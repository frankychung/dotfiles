return {
  {
    "f-person/auto-dark-mode.nvim",
    opts = {
      set_dark_mode = function()
        vim.opt.background = "dark"
        vim.cmd("colorscheme catppuccin-macchiato")
      end,
      set_light_mode = function()
        vim.opt.background = "light"
        vim.cmd("colorscheme catppuccin-latte")
      end,
    },
  },
}
