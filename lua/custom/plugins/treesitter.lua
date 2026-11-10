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

    -- Install missing parsers. Building needs these tools; they are only checked when a
    -- parser is actually missing, and a missing one warns once and skips installing.
    -- Existing parsers still highlight.
    local ts = require 'nvim-treesitter'
    local installed = ts.get_installed 'parsers'
    local missing = vim.tbl_filter(function(lang) return not vim.tbl_contains(installed, lang) end, languages)
    if #missing > 0 then
      local can_build = true
      for _, tool in ipairs { 'tree-sitter', 'cc', 'curl', 'tar' } do
        if not util.require_tool(tool, 'treesitter parser installs') then can_build = false end
      end
      if can_build then ts.install(missing) end
    end

    -- Enable treesitter highlighting when one of the target filetypes is opened.
    -- If treesitter fails for any reason (e.g. parser not installed), editing stays usable.
    vim.api.nvim_create_autocmd('FileType', {
      pattern = filetypes,
      callback = function(args) pcall(vim.treesitter.start, args.buf) end,
    })
  end,
}
