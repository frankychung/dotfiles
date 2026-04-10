vim.lsp.enable({ 'marksman', 'fsautocomplete', 'rescriptls', 'ts_ls' })

-- Workaround for nvim 0.12 bug: some LSP servers return invalid semantic token
-- lengths causing 100% CPU infinite loop. See neovim/neovim#36257.
-- Remove this once the bug is fixed upstream.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})
