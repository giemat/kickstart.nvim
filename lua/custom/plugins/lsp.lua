-- Main LSP configuration (language servers, LSP keymaps, and Mason installs).
-- How to change: add/remove servers in `servers`, tweak keymaps in the LspAttach callback,
-- or add extra tools in `ensure_installed`.
return {
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    { 'mason-org/mason.nvim', opts = {} },
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP.
    { 'j-hui/fidget.nvim', opts = {} },

    -- Allows extra capabilities provided by blink.cmp
    'saghen/blink.cmp',
  },
  config = function()
    -- Brief aside: **What is LSP?**
    --
    -- LSP is an initialism you've probably heard, but might not understand what it is.
    --
    -- LSP stands for Language Server Protocol. It's a protocol that helps editors
    -- and language tooling communicate in a standardized fashion.
    --
    -- In general, you have a "server" which is some tool built to understand a particular
    -- language (such as `clangd`, `lua_ls`, `pyright`, etc.). These Language Servers
    -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
    -- processes that communicate with some "client" - in this case, Neovim!
    --
    -- LSP provides Neovim with features like:
    --  - Go to definition
    --  - Find references
    --  - Autocompletion
    --  - Symbol Search
    --  - and more!
    --
    -- Thus, Language Servers are external tools that must be installed separately from
    -- Neovim. This is where `mason` and related plugins come into play.
    --
    -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
    -- and elegantly composed help section, `:help lsp-vs-treesitter`

    --  This function gets run when an LSP attaches to a particular buffer.
    --    That is to say, every time a new file is opened that is associated with
    --    an lsp (for example, opening `main.py` is associated with `pyright`) this
    --    function will be executed to configure the current buffer
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        -- NOTE: Remember that Lua is a real programming language, and as such it is possible
        -- to define small helper and utility functions so you don't have to repeat yourself.
        --
        -- In this case, we create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method('textDocument/documentHighlight', event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        --
        -- This may be unwanted, since they displace some of your code
        if client and client:supports_method('textDocument/inlayHint', event.buf) then
          map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    local util = require 'custom.util'

    -- Neovim detects compose files as plain `yaml`; the compose LS only attaches to `yaml.docker-compose`.
    vim.filetype.add {
      filename = {
        ['docker-compose.yml'] = 'yaml.docker-compose',
        ['docker-compose.yaml'] = 'yaml.docker-compose',
        ['compose.yml'] = 'yaml.docker-compose',
        ['compose.yaml'] = 'yaml.docker-compose',
      },
    }

    -- Language servers: lspconfig name -> Mason package, server binary, and whether it needs node.
    --  See `:help lsp-config` for the keys accepted in `config`.
    local servers = {
      clangd = { mason = 'clangd', bin = 'clangd' },
      basedpyright = { mason = 'basedpyright', bin = 'basedpyright-langserver' },
      bashls = { mason = 'bash-language-server', bin = 'bash-language-server', node = true },
      dockerls = { mason = 'dockerfile-language-server', bin = 'docker-langserver', node = true },
      docker_compose_language_service = { mason = 'docker-compose-language-service', bin = 'docker-compose-langserver', node = true },
      yamlls = { mason = 'yaml-language-server', bin = 'yaml-language-server', node = true },
      marksman = { mason = 'marksman', bin = 'marksman' },
      texlab = { mason = 'texlab', bin = 'texlab' },
      lua_ls = { mason = 'lua-language-server', bin = 'lua-language-server' },
    }

    -- Formatters, linters and debug adapters installed through Mason (consumed by conform, nvim-lint, nvim-dap).
    local tools = {
      { 'clang-format', bin = 'clang-format', feature = 'C/C++ formatting' },
      { 'ruff', bin = 'ruff', feature = 'Python formatting and linting' },
      { 'shfmt', bin = 'shfmt', feature = 'shell formatting' },
      { 'shellcheck', bin = 'shellcheck', feature = 'shell linting' },
      { 'hadolint', bin = 'hadolint', feature = 'Dockerfile linting' },
      { 'markdownlint', bin = 'markdownlint', feature = 'Markdown linting', node = true },
      { 'stylua', bin = 'stylua', feature = 'Lua formatting' },
      { 'codelldb', bin = 'codelldb', feature = 'C/C++ debugging' },
      { 'debugpy', bin = 'debugpy-adapter', feature = 'Python debugging' },
    }

    local has_node = util.has 'node'
    if not has_node then util.warn_missing('node', 'bashls, yamlls, dockerls, docker-compose LS, markdownlint') end

    -- Ensure the servers and tools above are installed (once; later starts are a no-op).
    --  To check the current status of installed tools, run `:Mason` (press `g?` for help).
    local ensure_installed = {}
    for name, server in vim.spairs(servers) do
      util.register(server.bin, name .. ' language server')
      if has_node or not server.node then table.insert(ensure_installed, server.mason) end
    end
    for _, tool in ipairs(tools) do
      util.register(tool.bin, tool.feature)
      if has_node or not tool.node then table.insert(ensure_installed, tool[1]) end
    end

    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    for name, server in pairs(servers) do
      if has_node or not server.node then
        local config = server.config or {}
        config.capabilities = vim.tbl_deep_extend('force', {}, capabilities, config.capabilities or {})
        vim.lsp.config(name, config)
        if name ~= 'lua_ls' then vim.lsp.enable(name) end
      end
    end

    -- Special Lua Config, as recommended by neovim help docs
    vim.lsp.config('lua_ls', {
      on_init = function(client)
        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
            --  See https://github.com/neovim/nvim-lspconfig/issues/3189
            library = vim.api.nvim_get_runtime_file('', true),
          },
        })
      end,
      settings = {
        Lua = {},
      },
    })
    vim.lsp.enable 'lua_ls'
  end,
}
