-- Markdown: in-buffer rendering (host and container) and a browser preview (host only).
-- Keys (buffer-local, markdown only):
--   <leader>mr  toggle in-buffer rendering
--   <leader>mp  toggle browser preview (in a container: one warning, no error)
-- How to change: edit `opts` below; to drop the browser preview remove the second spec.
local util = require 'custom.util'

-- The browser preview needs a host browser. The build downloads a prebuilt
-- binary (curl + tar), so node is not needed.
local preview_ok = not util.in_container()

local function preview()
  if util.in_container() then
    vim.notify('Browser preview unavailable in container', vim.log.levels.WARN)
    return
  end
  local plugin = require('lazy.core.config').plugins['markdown-preview.nvim']
  if vim.fn.exists ':MarkdownPreviewToggle' ~= 2 or not plugin then
    vim.notify('Browser preview unavailable: markdown-preview.nvim is not installed', vim.log.levels.WARN)
    return
  end
  if #vim.fn.glob(plugin.dir .. '/app/bin/markdown-preview-*', false, true) == 0 then
    vim.notify('Browser preview unavailable: prebuilt app missing, run :Lazy build markdown-preview.nvim', vim.log.levels.WARN)
    return
  end
  vim.cmd 'MarkdownPreviewToggle'
end

return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('custom-markdown-keys', { clear = true }),
        pattern = 'markdown',
        callback = function(args)
          vim.keymap.set('n', '<leader>mr', function() require('render-markdown').buf_toggle() end, {
            buffer = args.buf,
            desc = '[M]arkdown [R]ender toggle',
          })
          vim.keymap.set('n', '<leader>mp', preview, { buffer = args.buf, desc = '[M]arkdown browser [P]review' })
        end,
      })
    end,
    opts = {},
  },
  {
    'iamcco/markdown-preview.nvim',
    cond = preview_ok,
    ft = 'markdown',
    init = function() vim.g.mkdp_filetypes = { 'markdown' } end,
    build = function(plugin)
      -- Defensive: lazy skips `cond = false` plugins, but never download where preview is unused.
      if not preview_ok then return end
      -- Fetch the prebuilt app for the pinned version. Runs install.sh directly (not
      -- `mkdp#util#install`, which `lcd`s the focused window) and waits for it.
      local app = plugin.dir .. '/app'
      local version = vim.json.decode(table.concat(vim.fn.readfile(plugin.dir .. '/package.json'), '\n')).version
      local res = vim.system({ './install.sh', 'v' .. version }, { cwd = app }):wait()
      -- install.sh only warns (exit 0) when the download fails, so also check for the binary.
      if res.code ~= 0 or #vim.fn.glob(app .. '/bin/markdown-preview-*', false, true) == 0 then
        error('markdown-preview install.sh failed: ' .. (res.stderr or ''), 0)
      end
    end,
  },
}
