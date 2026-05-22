Config.now_if_args(function()
  local languages = {
    'fsharp',
    'css',
    'rescript',
    'javascript',
    'typescript',
    'tsx',
    'jsdoc',
    'rust',
  }

  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter (custom)')

  -- Inject CSS highlighting into F# triple-quoted strings.
  -- #offset! trims the surrounding `"""` so the CSS parser doesn't see them.
  vim.treesitter.query.set('fsharp', 'injections', [[
    ; Trigger: binding literally named `css`, e.g. `let css = """..."""`.
    ((function_or_value_defn
       (value_declaration_left
         (identifier_pattern
           (long_identifier_or_op (identifier) @_name)))
       body: (const (triple_quoted_string) @injection.content))
     (#eq? @_name "css")
     (#set! injection.language "css")
     (#offset! @injection.content 0 3 0 -3))

    ; Trigger: any binding preceded by a `// language=CSS` marker comment.
    ; Uses #lua-match? because #match? treats `=` as a vim-regex quantifier
    ; (e=CSS would mean optional `e` then `CSS`, which doesn't match `e=CSS`).
    ((line_comment) @_marker
     .
     (declaration_expression
       (function_or_value_defn
         body: (const (triple_quoted_string) @injection.content)))
     (#lua-match? @_marker "language=CSS")
     (#set! injection.language "css")
     (#offset! @injection.content 0 3 0 -3))
  ]])
end)
