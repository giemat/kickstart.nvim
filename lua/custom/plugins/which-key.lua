-- Useful plugin to show you pending keybinds.
-- How to change: adjust the `spec` groups or change the `delay`.
return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  opts = {
    -- delay between pressing a key and opening which-key (milliseconds)
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },

    -- Document existing key chains
    -- Group names live in lua/custom/cheatsheet.lua so the cheatsheet and which-key never drift.
    spec = (function()
      local spec = {}
      for _, g in ipairs(require('custom.cheatsheet').groups) do
        table.insert(spec, { g.prefix, group = g.name, mode = g.mode })
      end
      return spec
    end)(),
  },
}
