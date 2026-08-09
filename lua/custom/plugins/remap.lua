vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Open netrw file explorer.
-- How to change: remap `<leader>e` to any command you prefer.
vim.keymap.set('n', '<leader>e', vim.cmd.Ex)

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- F10 to compile and run the current C++ file.
-- How to change: edit flags in the `g++` command below.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'cpp',
  callback = function(event)
    vim.keymap.set('n', '<F10>', function()
      vim.cmd 'write'
      local file = vim.fn.expand '%:p'
      local output = vim.fn.expand '%:p:r'
      local cmd = string.format('g++ -std=c++17 "%s" -o "%s" && "%s"', file, output, output)
      vim.cmd('!' .. cmd)
    end, { buffer = event.buf, desc = 'Compile and run C++ file' })
  end,
})

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
-- CapsLock is remapped globally to Escape in Hyprland (`caps:escape`), so
-- using `<Esc>` here also works when you press CapsLock.
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR><Esc>', { desc = 'Clear search highlight' })

-- Run `:Copilot` from normal mode with Ctrl+i.
-- How to change: replace `<C-i>` or call another Copilot subcommand.
vim.keymap.set('n', '<C-i>', '<cmd>Copilot<CR>', { desc = 'Copilot command' })

-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Teest shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { float = true },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

return {}
