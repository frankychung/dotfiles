return {
  -- Ionide-vim for F# support
  {
    "ionide/Ionide-vim",
    ft = { "fsharp" },
    config = function()
      -- Configure F# backend to use Neovim's built-in LSP
      vim.g["fsharp#backend"] = "nvim"
      vim.g["fsharp#automatic_workspace_init"] = 1
      vim.g["fsharp#workspace_mode_peek_deep_level"] = 2
      vim.g["fsharp#exclude_project_directories"] = { "paket-files" }
    end,
  },

  -- LSP configuration for F#
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        fsautocomplete = {
          cmd = { "fsautocomplete", "--background-service-enabled" },
          filetypes = { "fsharp" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("*.sln", "*.fsproj", ".git")(fname)
          end,
          init_options = {
            AutomaticWorkspaceInit = true,
          },
          settings = {
            FSharp = {
              keywordsAutocomplete = true,
              externalAutocomplete = false,
              linter = true,
              unionCaseStubGeneration = true,
              unionCaseStubGenerationBody = "failwith \"Not Implemented\"",
              recordStubGeneration = true,
              recordStubGenerationBody = "failwith \"Not Implemented\"",
              interfaceStubGeneration = true,
              interfaceStubGenerationObjectIdentifier = "this",
              interfaceStubGenerationMethodBody = "failwith \"Not Implemented\"",
              unusedOpensAnalyzer = true,
              unusedDeclarationsAnalyzer = true,
              simplifyNameAnalyzer = true,
              resolveNamespaces = true,
              enableReferenceCodeLens = true,
              enableAnalyzers = true,
              analyticsAutocomplete = {
                enabled = false,
              },
            },
          },
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
}