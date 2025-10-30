return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        fsautocomplete = {
          cmd = { "fsautocomplete", "--background-service-enabled" },
        },
      },
    },
  },

  -- Ensure treesitter has F# support
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = opts.ensure_installed or {}
        vim.list_extend(opts.ensure_installed, { "fsharp" })
      end
    end,
  },

  -- Neotest adapter for .NET
  { "nsidorenco/neotest-vstest" },
  {
    "nvim-neotest/neotest",
    opts = {
      log_level = vim.log.levels.DEBUG,
      adapters = {
        ["neotest-vstest"] = {},
      },
    },
  },
}
