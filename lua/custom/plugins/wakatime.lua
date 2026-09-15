-- WakaTime time tracking. Only enabled where credentials exist (host), so
-- fresh containers without ~/.wakatime.cfg or WAKATIME_API_KEY start clean.
return {
  'wakatime/vim-wakatime',
  lazy = false,
  enabled = vim.env.WAKATIME_API_KEY ~= nil or vim.fn.filereadable(vim.fn.expand '~/.wakatime.cfg') == 1,
}
