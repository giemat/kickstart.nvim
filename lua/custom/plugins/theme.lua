-- Colorscheme.
-- How to change: replace the plugin name and update `vim.cmd.colorscheme`.
--return {
--  'folke/tokyonight.nvim',
--  priority = 1000, -- Make sure to load this before all the other start plugins.
--  config = function()
--    ---@diagnostic disable-next-line: missing-fields
--    require('tokyonight').setup {
--      styles = {
--        comments = { italic = false }, -- Disable italics in comments
--      },
--    }
--
--    -- Load the colorscheme here.
--    -- Like many other themes, this one has different styles, and you could load
--    -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
--    vim.cmd.colorscheme 'tokyonight-night'
--  end,
--}
--
return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000, -- Ensure it loads before other plugins
    config = function()
      require('catppuccin').setup {
        flavour = 'mocha', -- latte, frappe, macchiato, mocha
        transparent_background = false,
        term_colors = true,
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          treesitter = true,
          notify = true,
          mini = {
            enabled = true,
            indentscope_color = '',
          },
        },
      }

      -- Actually load the theme here
      vim.cmd.colorscheme 'catppuccin'
    end,
  },
}
