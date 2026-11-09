-- Colorscheme.
-- How to change: replace the plugin name and update `vim.cmd.colorscheme`.
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
          blink_cmp = true,
          gitsigns = true,
          neotree = true,
          treesitter = true,
          which_key = true,
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
