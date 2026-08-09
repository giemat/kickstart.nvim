-- Treesitter for better syntax highlighting and parsing.
-- How to change: add/remove languages in `languages`.
return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local languages = {
      -- Requested languages
      'c',
      'cpp',
      'go',
      'python',
      'lua',

      -- Useful for Neovim config files and query files
      'vim',
      'vimdoc',
      'query',
    }

    -- Install/update parsers. This is safe to run on startup.
    -- It is a no-op for already installed parsers.
    require('nvim-treesitter').install(languages)

    -- Enable treesitter highlighting when one of the target filetypes is opened.
    -- If treesitter fails for any reason, this keeps editing usable.
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'c', 'cpp', 'go', 'python', 'lua' },
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
