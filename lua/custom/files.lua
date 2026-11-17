local group = vim.api.nvim_create_augroup('custom-files', { clear = true })
local pending = {}

local function save(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  local bo = vim.bo[buf]
  if bo.buftype ~= '' or not bo.modified or not bo.modifiable or bo.readonly then return end
  if bo.filetype == 'gitcommit' or bo.filetype == 'gitrebase' or vim.api.nvim_buf_get_name(buf) == '' then return end
  vim.api.nvim_buf_call(buf, function() vim.cmd 'silent! update' end)
end

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
  group = group,
  desc = 'Save one second after the last edit',
  callback = function(event)
    local token = {}
    pending[event.buf] = token
    vim.defer_fn(function()
      if pending[event.buf] ~= token then return end
      pending[event.buf] = nil
      save(event.buf)
    end, 1000)
  end,
})

vim.api.nvim_create_autocmd({ 'BufLeave', 'FocusLost' }, {
  group = group,
  desc = 'Save when leaving a buffer or window',
  callback = function(event) save(event.buf) end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
  group = group,
  callback = function(event) pending[event.buf] = nil end,
})

vim.o.autoread = true
local function check()
  if vim.fn.mode():match '^[cR!t]' or vim.fn.getcmdwintype() ~= '' then return end
  vim.cmd 'checktime'
end

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  group = group,
  desc = 'Check for external file changes',
  callback = check,
})

local timer = assert(vim.uv.new_timer())
timer:start(1000, 1000, vim.schedule_wrap(check))
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = group,
  callback = function()
    timer:stop()
    timer:close()
  end,
})
