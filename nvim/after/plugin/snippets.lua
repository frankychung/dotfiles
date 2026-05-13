-- Wire up snippet expand/navigate into Tab/S-Tab multisteps
-- Show snippets in completion menu via in-process LSP server
Config.later(function()
  MiniKeymap.map_multistep('i', '<Tab>', { 'minisnippets_next', 'minisnippets_expand', 'pmenu_next' })
  MiniKeymap.map_multistep('i', '<S-Tab>', { 'minisnippets_prev', 'pmenu_prev' })
  MiniSnippets.start_lsp_server()
end)
