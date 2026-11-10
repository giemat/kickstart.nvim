-- Treesitter for better syntax highlighting and parsing.
-- How to change: add/remove parsers in `languages` and their filetypes in `filetypes`.
return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local util = require 'custom.util'

    local languages = {
      'c',
      'cpp',
      'python',
      'lua',
      'bash',
      'dockerfile',
      'yaml',
      'markdown',
      'markdown_inline',
      'latex',
      'bibtex',

      -- Useful for Neovim config files and query files
      'vim',
      'vimdoc',
      'query',
    }

    local filetypes = {
      'c',
      'cpp',
      'python',
      'lua',
      'sh',
      'bash',
      'dockerfile',
      'yaml',
      'yaml.docker-compose',
      'markdown',
      'tex',
      'plaintex',
      'bib',
      'vim',
      'help',
      'query',
    }

    -- Install missing parsers (a no-op for installed ones). Building needs these tools;
    -- when one is missing, warn once and skip installing. Existing parsers still highlight.
    local can_build = true
    for _, tool in ipairs { 'tree-sitter', 'cc', 'curl', 'tar' } do
      if not util.require_tool(tool, 'treesitter parser installs') then can_build = false end
    end
    if can_build then require('nvim-treesitter').install(languages) end

    -- Enable treesitter highlighting when one of the target filetypes is opened.
    -- If treesitter fails for any reason (e.g. parser not installed), editing stays usable.
    vim.api.nvim_create_autocmd('FileType', {
      pattern = filetypes,
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft) or ft:match '^[^.]+'
        pcall(vim.treesitter.start, args.buf, lang)
      end,
    })
  end,
}
