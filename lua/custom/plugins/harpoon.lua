-- Harpoon: pin a handful of files and jump between them.
-- https://github.com/ThePrimeagen/harpoon/tree/harpoon2
-- How to change: edit the keys below; add more `<leader>N` slots by copying one.

local function harpoon() return require 'harpoon' end

local function select_slot(n)
  return function() harpoon():list():select(n) end
end

return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function() harpoon():setup() end,
  keys = {
    { '<leader>a', function() harpoon():list():add() end, desc = 'Harpoon: [A]dd file' },
    {
      '<leader>A',
      function()
        local h = harpoon()
        h.ui:toggle_quick_menu(h:list())
      end,
      desc = 'Harpoon: toggle menu',
    },
    { '<leader>1', select_slot(1), desc = 'Harpoon: go to file 1' },
    { '<leader>2', select_slot(2), desc = 'Harpoon: go to file 2' },
    { '<leader>3', select_slot(3), desc = 'Harpoon: go to file 3' },
    { '<leader>4', select_slot(4), desc = 'Harpoon: go to file 4' },
  },
}
