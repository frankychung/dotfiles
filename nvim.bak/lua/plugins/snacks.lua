return {
  "folke/snacks.nvim",
  opts = {
    zen = {
      toggles = {
        dim = true,
        git_signs = false,
        mini_diff_signs = false,
        diagnostics = false,
        inlay_hints = false,
      },
      on_open = function()
        vim.b.completion = false
      end,
      on_close = function()
        vim.b.completion = true
      end,
    },
  },
}
