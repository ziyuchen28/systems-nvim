 
--  1. BOOTSTRAP LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

--  2. PLUGINS
require("lazy").setup({
  -- Core Utilities
  { "nvim-lua/plenary.nvim" },
  { "numToStr/Comment.nvim", opts = {} }, 
  
  -- LSP & Completion
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", opts = {} },
  { "williamboman/mason-lspconfig.nvim" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },

  -- Highlighting & Navigation (FIXED: Explicit config to prevent crash)
  { 
    "nvim-treesitter/nvim-treesitter", 
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "c", "cpp", "lua", "vim", "bash", "cmake", "make" },
        highlight = { enable = true },
        indent    = { enable = false },
      })
    end
  },
  { "nvim-telescope/telescope.nvim" },

  -- UI & Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        section_separators = '',
        component_separators = '|',
        theme = 'auto',
      },
      sections = {
        lualine_c = { { 'filename', path = 1 } }, 
      },
    }
  },
  { "akinsho/bufferline.nvim", dependencies = "nvim-tree/nvim-web-devicons", opts = {} },
  
  -- TODO Comments
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      signs = false,
      highlight = {
        keyword = "fg",
        pattern = [[\v(KEYWORDS)]], 
      },
      gui_style = { fg = "NONE", bg = "NONE" },
    }
  },
})

--  3. GENERAL SETTINGS
vim.g.mapleader = " "

-- UI Options
vim.opt.ignorecase    = true
vim.opt.termguicolors = true
vim.opt.number        = false    -- Show line numbers
vim.opt.relativenumber= false  -- DISABLE relative numbers
vim.opt.scrolloff     = 6
vim.opt.cursorline    = false  -- DISABLE highlight line

-- Indentation
vim.opt.tabstop     = 4
vim.opt.shiftwidth  = 4
vim.opt.expandtab   = true
vim.opt.autoindent  = true
vim.opt.smartindent = false 
vim.opt.cindent     = false 

-- Performance
vim.opt.updatetime  = 200
vim.opt.timeoutlen  = 300
vim.opt.lazyredraw  = true

--  4. WSL CLIPBOARD SETUP
vim.opt.clipboard = "unnamedplus"
if vim.fn.has("wsl") == 1 then
    vim.g.clipboard = {
        name = "WslClipboard",
        copy = {
            ["+"] = "win32yank.exe -i --crlf",
            ["*"] = "win32yank.exe -i --crlf",
        },
        paste = {
            ["+"] = "win32yank.exe -o --lf",
            ["*"] = "win32yank.exe -o --lf",
        },
        cache_enabled = 0,
    }
end

--  5. LSP & COMPLETION (CLANGD)

require("mason").setup()

require("mason-lspconfig").setup({
  ensure_installed = { "clangd" },

  -- We configure and enable clangd ourselves below.
  automatic_enable = false,
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities.offsetEncoding = { "utf-8" }

-- Prefer Mason's clangd; fall back to clangd from PATH.
local mason_clangd = vim.fn.stdpath("data") .. "/mason/bin/clangd"
local clangd = vim.fn.executable(mason_clangd) == 1
    and mason_clangd
    or "clangd"

local function find_compile_commands_dir(root_dir)
  if not root_dir then
    return nil
  end

  local patterns = {
    root_dir .. "/compile_commands.json",
    root_dir .. "/build/compile_commands.json",
    root_dir .. "/build/*/compile_commands.json",
    root_dir .. "/out/compile_commands.json",
    root_dir .. "/out/*/compile_commands.json",
  }

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.glob(pattern, false, true)
    table.sort(matches)

    if #matches > 0 then
      return vim.fs.dirname(matches[1])
    end
  end

  return nil
end

vim.lsp.config("clangd", {
  cmd = {
    clangd,
    "--background-index",
    "--clang-tidy",
    "--header-insertion=never",
    "--completion-style=detailed",
  },

  filetypes = {
    "c",
    "cpp",
    "objc",
    "objcpp",
    "cuda",
  },

  root_markers = {
    "compile_commands.json",
    ".git",
    "CMakeLists.txt",
  },

  capabilities = capabilities,

  before_init = function(params, config)
    local cdb_dir = find_compile_commands_dir(config.root_dir)

    if cdb_dir then
      params.initializationOptions =
          params.initializationOptions or {}

      params.initializationOptions.compilationDatabasePath =
          cdb_dir
    end
  end,
})

vim.lsp.enable("clangd")

-- Autocompletion Setup
local cmp = require("cmp")
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>']      = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
  }),
})


--  6. TELESCOPE & KEYMAPS
require('telescope').setup{
  defaults = {
    layout_config = { prompt_position = "top" },
    sorting_strategy = "ascending",
    file_ignore_patterns = { "%.git/", "build/", "external/" },
  }
}

local builtin = require('telescope.builtin')

-- Files
-- vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>ff', function()
  require('telescope.builtin').find_files({ hidden = true })
end, {})

-- ALL files (shows hidden AND ignores .gitignore)
vim.keymap.set('n', '<leader>fa', function()
  require('telescope.builtin').find_files({ hidden = true, no_ignore = true })
end, { desc = "Find all files (no ignore)" })

vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})

-- Buffer Navigation
vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", {})
vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", {})
vim.keymap.set("n", "<leader>q", ":bnext | bd #<CR>", { desc = "Close buffer" })

-- LSP
-- vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to Definition' })
vim.keymap.set('n', 'gd', builtin.lsp_definitions, { desc = 'Go to Definition' })
vim.keymap.set('n', 'gD', vim.lsp.buf.type_definition, { desc = 'Go to Type' })
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to Impl' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Show Error" })

-- Fast Movement
vim.keymap.set('n', '<A-j>', '5j', { noremap = true, silent = true })
vim.keymap.set('n', '<A-k>', '5k', { noremap = true, silent = true })

--  7. CUSTOM THEME: MINIMAL STYLE
local function apply_minimal()
  vim.cmd("hi clear")
  vim.cmd("syntax reset")
  vim.g.colors_name = "minimal"

  -- Palette
  local bg      = "#0b2424" -- Dark Teal / Blackboard
  local fg      = "#d0c890" -- Parchment
  local comment = "#6aa06a" -- Sage Green
  local str     = "#80f0ff" -- Cyan
  local num     = "#80c0ff" -- Soft Blue
  local kw      = "#e0f0ff" -- Blue-White
  
  local hi = function(g, val) vim.api.nvim_set_hl(0, g, val) end

  -- Editor Base
  hi("Normal",       { fg=fg, bg=bg })
  hi("LineNr",       { fg="#142f2f", bg=bg }) 
  hi("Visual",       { bg="#0000ff" })        
  
  -- Syntax
  hi("Comment",      { fg=comment })
  hi("String",       { fg=str })
  -- hi("Number",       { fg=num, bold=true })
  -- hi("Float",        { fg=num, bold=true })
  hi("Function",     { fg=fg }) 
  hi("Identifier",   { fg=fg }) 

  -- hi("Keyword",      { fg=kw, bold=true })
  -- hi("Statement",    { fg=kw, bold=true })
  -- hi("Type",         { fg=fg, bold=true }) 

  -- hi("PreProc",      { fg="#f8f8f2", bold=true }) 
  -- hi("@keyword.directive", { fg="#f8f8f2", bold=true })


  hi("Number",    { fg=num })
  hi("Float",     { fg=num })

  hi("Keyword",   { fg=kw })
  hi("Statement", { fg=kw })
  hi("Type",      { fg=fg })

  hi("PreProc",   { fg="#f8f8f2" })
  hi("@keyword.directive", { fg="#f8f8f2" })


  hi("DiagnosticUnnecessary", { link="Comment" }) 
end

apply_minimal()

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then client.server_capabilities.semanticTokensProvider = nil end
  end,
})

