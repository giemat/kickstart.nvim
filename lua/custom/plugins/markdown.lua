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
  if vim.fn.exists ':MarkdownPreviewToggle' ~= 2 then
    vim.notify('Browser preview unavailable: markdown-preview.nvim is not installed', vim.log.levels.WARN)
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
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    init = function() vim.g.mkdp_filetypes = { 'markdown' } end,
    build = function()
      -- lazy still installs `cond = false` plugins; skip the download where it is never used.
      if not preview_ok then return end
      -- Load the plugin first so `mkdp#util#install_sync` exists, then fetch the prebuilt app.
      require('lazy').load { plugins = { 'markdown-preview.nvim' }, wait = true }
      vim.fn['mkdp#util#install_sync']()
    end,
  },
}
