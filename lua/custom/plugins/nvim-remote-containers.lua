-- Container support:
--  * nvim-remote-containers: attach Neovim into a running container (`:AttachToContainer`, ...).
--  * custom.devcontainer: `:DcUp` / `:DcRe` / `:DcIn` / `:DcInW` wrappers around the
--    `devcontainer` CLI with dotfiles injection (see lua/custom/devcontainer.lua).
return {
  'jamestthompson3/nvim-remote-containers',
  config = function() require('custom.devcontainer').setup() end,
}
