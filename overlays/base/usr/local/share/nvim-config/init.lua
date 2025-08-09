-- mini.nvim
local path_package = vim.fn.stdpath('data') .. '/site'
local mini_path = path_package .. '/pack/deps/start/mini.nvim'
if not vim.loop.fs_stat(mini_path) then
    vim.cmd('echo "Installing `mini.nvim`" | redraw')
    local clone_cmd = {
        'git', 'clone', '--filter=blob:none',
        'https://github.com/echasnovski/mini.nvim', mini_path
    }
    vim.fn.system(clone_cmd)
    vim.cmd('packadd mini.nvim | helptags ALL')
    vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- options
vim.g.mapleader = ' '
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'
vim.o.cursorcolumn = false
vim.o.cursorline = true
vim.o.wrap = false
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.swapfile = false
vim.o.background = 'dark'
vim.o.winborder = 'rounded'
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.termguicolors = true
vim.o.incsearch = true
vim.o.undofile = true
vim.o.scrolloff = 10
vim.o.sidescrolloff = 8
vim.o.clipboard = 'unnamedplus'

-- builtin configs
local map = vim.keymap.set
map('n', '<leader>w', ':write<CR>', { desc = 'write' })
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ higroup = "YankedText", timeout = 200 })
    end
})
local function source_config()
    vim.cmd.source('~/.config/nvim/init.lua')
end
map('n', '<leader>r', source_config, { desc = 're-source config' })

--
-- pugin configuration
--

-- plugin installation
require 'mini.deps'.setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
add({ source = 'ellisonleao/gruvbox.nvim' })
add({
    source = 'neovim/nvim-lspconfig',
    depends = { 'williamboman/mason.nvim' },
})
add({
    source = 'nvim-treesitter/nvim-treesitter',
    checkout = 'master',
    monitor = 'main',
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
})
add({
    source = 'WhoIsSethDaniel/mason-tool-installer.nvim',
    depends = { 'mason-org/mason-lspconfig.nvim' },
})
add({
    source = 'mfussenegger/nvim-lint',
})
add({
    source = 'rachartier/tiny-inline-diagnostic.nvim'
})
add({
    source = 'aaronik/treewalker.nvim'
})

-- workflow
now(function() require 'mini.icons'.setup() end)
now(function() require 'mini.tabline'.setup() end)
later(function() require 'mini.git'.setup() end)
later(function() require 'mini.diff'.setup() end)
later(function() require 'mini.statusline'.setup() end)
later(function() require 'mini.notify'.setup() end)
later(function()
    local trailspace = require 'mini.trailspace'
    trailspace.setup()
    vim.api.nvim_create_autocmd('BufWritePre', { callback = function() trailspace.trim() end })
end)
later(function() require 'mini.surround'.setup() end)
later(function() require 'mini.pairs'.setup() end)
later(function()
    require 'mini.pick'.setup()
    map('n', '<leader>f', ':Pick files<CR>', { desc = 'find' })
end)
later(function()
    local minifiles = require 'mini.files'
    minifiles.setup({
        windows = {
            preview = true,
            width_preview = 80,
        },
    })
    map('n', '<leader>e', minifiles.open, { desc = 'explore' })
end)
later(function()
    require 'treewalker'.setup()
    map({ 'n', 'v', 'x' }, '<leader>j', '<cmd>Treewalker Down<CR>', { silent = true, desc = 'walk down' })
    map({ 'n', 'v', 'x' }, '<leader>k', '<cmd>Treewalker Up<CR>', { silent = true, desc = 'walk up' })
    map({ 'n', 'v', 'x' }, '<leader>l', '<cmd>Treewalker Right<CR>', { silent = true, desc = 'walk right' })
    map({ 'n', 'v', 'x' }, '<leader>h', '<cmd>Treewalker Left<CR>', { silent = true, desc = 'walk left' })
end)
later(function()
    local miniclue = require 'mini.clue'
    miniclue.setup({
        triggers = {
            { mode = 'n', keys = '<leader>' },
            { mode = 'i', keys = '<C-x>' },
            { mode = 'n', keys = 'g' },
            { mode = 'x', keys = 'g' },
            { mode = 'n', keys = '"' },
            { mode = 'x', keys = '"' },
            { mode = 'i', keys = '<C-r>' },
            { mode = 'c', keys = '<C-r>' },
            { mode = 'n', keys = '<C-w>' },
            { mode = 'n', keys = 'z' },
            { mode = 'x', keys = 'z' },
        },

        clues = {
            { mode = 'n', keys = '<leader>b', desc = '+buffer' },
            miniclue.gen_clues.builtin_completion(),
            miniclue.gen_clues.g(),
            miniclue.gen_clues.marks(),
            miniclue.gen_clues.registers(),
            miniclue.gen_clues.windows(),
            miniclue.gen_clues.z(),
        },

        window = {
            delay = 500,
        },
    })
end)
later(function()
    require 'mini.bufremove'.setup()
    map('n', '<leader>bd', ':lua MiniBufremove.delete()<CR>', { desc = 'delete' })
end)
later(function() require 'mini.comment'.setup() end)
later(function()
    local gen_ai_spec = require 'mini.extra'.gen_ai_spec
    require 'mini.ai'.setup({
        custom_textobjects = {
            B = gen_ai_spec.buffer(),
            D = gen_ai_spec.diagnostic(),
            I = gen_ai_spec.indent(),
            L = gen_ai_spec.line(),
            N = gen_ai_spec.number(),
        },
    })
end)
later(function()
    require 'tiny-inline-diagnostic'.setup()
    vim.diagnostic.config({ virtual_ext = false })
end)

-- treesitter/lsp/autocomplete/etc
now(function()
    require 'mason'.setup({
        ui = {
            icons = {
                package_installed = '✓',
                package_pending = '➜',
                package_uninstalled = '✗'
            }
        }
    })
end)
now(function() require 'mason-lspconfig'.setup() end)
now(function()
    require 'mason-tool-installer'.setup({
        ensure_installed = {
            'lua_ls',
            'pyright',
            'dockerls',
            'yamlls',
            'helm_ls',
            'vale',
            'vale_ls',
        },
        auto_update = true,
        integrations = {
            ['mason-lspconfig'] = true,
        },
    })
end)
now(function()
    require 'nvim-treesitter.configs'.setup({
        ensure_installed = {
            'lua',
            'vimdoc',
            'dockerfile',
        },
        highlight = { enable = true },
        auto_install = true,
    })
end)
later(function()
    vim.lsp.enable({
        'bashls',
        'rust_analyzer',
        'gopls',
        'rpmspec',
        'lua_ls',
        'pyright',
        'dockerls',
        'yamlls',
        'helm_ls',
        'vale_ls',
    })
end)
later(function() map('n', '<leader>F', vim.lsp.buf.format, { desc = 'format' }) end)
later(function()
    require 'lint'.linters_by_ft = {
        markdown = { 'vale' },
        dockerfile = { 'hadolint' },
    }
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        callback = function()
            require("lint").try_lint()
        end,
    })
end)
later(function()
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            if client ~= nil and client:supports_method('textDocument/completion') and vim.lsp.completion then
                vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
            end
        end,
    })
    vim.cmd('set completeopt+=noselect')
end)
later(function()
    require 'mini.cursorword'.setup()
end)

-- theme
now(function()
    vim.cmd.colorscheme('gruvbox')
    vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
    vim.api.nvim_set_hl(0, 'NormalNC', { bg = 'none' })
    vim.api.nvim_set_hl(0, 'EndOfBuffer', { bg = 'none' })
    vim.api.nvim_set_hl(0, "YankedText", { bg = "#527252" })
end)
