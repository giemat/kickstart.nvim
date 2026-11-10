-- LaTeX: vimtex compiles with latexmk on save and views with zathura on the host.
-- Inside a container it only compiles; the PDF lands in the mounted folder and a host viewer reloads it.
-- Missing latexmk or zathura: one warning on the first .tex buffer, that feature is disabled,
-- editing, texlab and treesitter keep working.
-- Maps are vimtex defaults under <localleader>l (= <leader>l): ll compile, lv view, lk stop, lc clean.
local util = require 'custom.util'

util.register('latexmk', 'LaTeX compile')
if not util.in_container() then util.register('zathura', 'LaTeX PDF view') end

return {
  'lervag/vimtex',
  lazy = false, -- vimtex must not be lazy-loaded
  init = function()
    -- Treesitter highlights tex (treesitter.lua). Turning vimtex syntax off also stops its
    -- "Syntax highlighting is controlled by Treesitter" warning on every tex buffer.
    vim.g.vimtex_syntax_enabled = 0
    vim.g.vimtex_compiler_method = 'latexmk'
    -- Single-shot compiles: save triggers one, so continuous latexmk would double up.
    vim.g.vimtex_compiler_latexmk = { continuous = 0 }

    local has_latexmk = util.has 'latexmk'
    if not has_latexmk then vim.g.vimtex_compiler_enabled = 0 end

    local view_tool = nil
    if util.in_container() then
      vim.g.vimtex_view_enabled = 0
    elseif util.has 'zathura' then
      -- vimtex's 'zathura' method finds the open window with xdotool (X11 only); without it every
      -- view opens a new window. 'zathura_simple' lets zathura forward the search over D-Bus instead.
      local xdo = util.has 'xdotool' and vim.env.WAYLAND_DISPLAY == nil
      vim.g.vimtex_view_method = xdo and 'zathura' or 'zathura_simple'
    else
      vim.g.vimtex_view_enabled = 0
      view_tool = 'zathura'
    end

    local group = vim.api.nvim_create_augroup('custom-vimtex', { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'tex',
      callback = function(args)
        if not has_latexmk then util.warn_missing('latexmk', 'LaTeX compile') end
        if view_tool then util.warn_missing(view_tool, 'LaTeX PDF view') end
        if has_latexmk then
          -- FileType can fire again for the same buffer (:e, :set ft); keep one save hook.
          vim.api.nvim_clear_autocmds { group = group, buffer = args.buf }
          vim.api.nvim_create_autocmd('BufWritePost', {
            group = group,
            buffer = args.buf,
            desc = 'vimtex: compile on save',
            callback = function()
              local ok, err = pcall(vim.cmd, 'VimtexCompileSS')
              if not ok then vim.notify('vimtex compile on save failed: ' .. tostring(err), vim.log.levels.ERROR) end
            end,
          })
        end
      end,
    })
  end,
}
