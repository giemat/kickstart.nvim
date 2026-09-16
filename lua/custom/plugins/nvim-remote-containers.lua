-- Container support:
--  * nvim-remote-containers: attach Neovim into a running container (`:AttachToContainer`, ...).
--  * custom.devcontainer: `:DcUp` / `:DcRe` / `:DcIn` / `:DcInW` call
--    myubuntu/myubuntu/devcontainer-up.sh and devcontainer-exec.sh (local inject).
return {
  'jamestthompson3/nvim-remote-containers',
  config = function() require('custom.devcontainer').setup() end,
}
