return {
  -- ReScript syntax highlighting and filetype support
  {
    "rescript-lang/vim-rescript",
    ft = { "rescript" },
    build = ":TSUpdate rescript",
  },

  -- LSP configuration for ReScript
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rescriptls = {
          cmd = { "rescript-language-server", "--stdio" },
          filetypes = { "rescript" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("bsconfig.json", "rescript.json")(fname)
          end,
          settings = {},
        },
      },
    },
  },

  -- Ensure treesitter has rescript support
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = opts.ensure_installed or {}
        vim.list_extend(opts.ensure_installed, { "rescript" })
      end
    end,
  },
}