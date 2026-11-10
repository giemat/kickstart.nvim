-- Devcontainer support lives in lua/custom/devcontainer.lua (no plugin).
-- A virtual lazy spec runs its setup() at startup: `:DcUp` / `:DcRe` /
-- `:DcIn` / `:DcInW` / `:DcReopen` and the `<leader>d` keymaps.
return {
  'devcontainer',
  virtual = true,
  lazy = false,
  config = function() require('custom.devcontainer').setup() end,
}
