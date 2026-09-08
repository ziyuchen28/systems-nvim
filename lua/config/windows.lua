 local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
 if not vim.loop.fs_stat(lazypath) then
   print("lazy.nvim not found!")
 end
 vim.opt.rtp:prepend(lazypath)

 -- INSTALL PLUGINS
 require("lazy").setup({
   --{ "neovim/nvim-lspconfig" },
   {
     "numToStr/Comment.nvim",
     config = function()
       require("Comment").setup()
     end
   },
   {
     "neovim/nvim-lspconfig",
     lazy = false,
   },
   { "williamboman/mason.nvim" },
   { "williamboman/mason-lspconfig.nvim" },
   { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
   { "hrsh7th/nvim-cmp" },
   { "hrsh7th/cmp-nvim-lsp" },
   { "nvim-lua/plenary.nvim" },
   -- { "morhetz/gruvbox" }, 
   -- { "jacoborus/tender.vim" },
   { "nvim-telescope/telescope.nvim" },
   {
     "nvim-lualine/lualine.nvim",
     dependencies = { "nvim-tree/nvim-web-devicons" },
     config = function()
         require("lualine").setup({
             options = {
                 theme = "auto",
                 section_separators = "",
                 component_separators = "|",
             },
             sections = {
                 lualine_c = {
                     { "filename", path = 1, shorting_target = 40 },
                 },
             },
         })
     end
   },

   {
     "akinsho/bufferline.nvim",
     version = "*",
     dependencies = "nvim-tree/nvim-web-devicons",
     config = function()
       require("bufferline").setup()
     end,
   },
 {
   "folke/todo-comments.nvim",
   lazy = false,  -- load at startup so we can refresh right after theme
   dependencies = { "nvim-lua/plenary.nvim" },
   opts = {
     signs = false,                -- no gutter signs/icons
     keywords = {
       TODO = { icon = "", color = "error", alt = { "TO DO", "to do" } },
     },
     highlight = {
       multiline     = false,                 -- never across lines
       before        = "",                    -- don't color before keyword
       after         = "",                    -- don't color after keyword
       keyword       = "fg",                  -- only the word is colored
       comments_only = true,                  -- only inside comments
       -- Allow phrases with a space (TO DO). No background.
       pattern       = [[\v(KEYWORDS)]],      -- very-magic: match ANY of KEYWORDS text
     },
     gui_style = { fg = "NONE", bg = "NONE" },
     colors = { error = { "#ff3030" } },     -- bright red
     search  = { pattern = [[\v(KEYWORDS)]] }, -- Telescope/rg match same phrases
   },
 }
 })



 -- === Options ===
 vim.o.timeoutlen  = 300   -- faster <leader> combos
 vim.o.ttimeoutlen = 10
 vim.o.updatetime  = 200   -- quicker CursorHold/diagnostics

 vim.o.relativenumber = false
 vim.o.scrolloff      = 6

 vim.o.lazyredraw = true


 -- Enable LSP and clangd
 require("mason").setup()

 require("mason-lspconfig").setup({
   ensure_installed = { "clangd" },

   -- Prevent mason-lspconfig from starting clangd with default settings.
   automatic_enable = false,
 })

 local lspconfig = require("lspconfig")
 local util = require("lspconfig.util")

 local function normalize_path_local(path)
   return path:gsub("\\", "/")
 end

 local function find_compile_commands_dir(root_dir)
   if not root_dir then
     return nil
   end

   local root = normalize_path_local(root_dir)

   local patterns = {
     root .. "/compile_commands.json",
     root .. "/out/compile_commands.json",
     root .. "/out/*/compile_commands.json",
     root .. "/build/compile_commands.json",
     root .. "/build/*/compile_commands.json",
   }

   for _, pattern in ipairs(patterns) do
     local matches = vim.fn.glob(pattern, false, true)
     table.sort(matches)

     for _, file in ipairs(matches) do
       if vim.fn.filereadable(file) == 1 then
         return normalize_path_local(vim.fn.fnamemodify(file, ":h"))
       end
     end
   end

   return nil
 end

 local clangd_capabilities = require("cmp_nvim_lsp").default_capabilities()
 clangd_capabilities.offsetEncoding = { "utf-8" }

 lspconfig.clangd.setup({
   capabilities = clangd_capabilities,

   root_dir = function(fname)
     return util.root_pattern(".git", "compile_commands.json", "compile_flags.txt", ".clangd", "CMakeLists.txt")(fname)
         or util.find_git_ancestor(fname)
   end,

   cmd = {
     "clangd",
     "--background-index",
     "--clang-tidy",
     "--clang-tidy-checks=-clang-diagnostic-unused-include",
     "--completion-style=detailed",
     "--header-insertion=never",
   },

   on_new_config = function(new_config, root_dir)
     local cdb_dir = find_compile_commands_dir(root_dir)

     if cdb_dir then
       new_config.cmd = vim.deepcopy(new_config.cmd)
       table.insert(new_config.cmd, "--compile-commands-dir=" .. cdb_dir)
     end
   end,
 })



 -- LSP for rust-analyzer
 local function normalize_path(path)
   return path:gsub("\\", "/")
 end



 local function dedupe_paths(paths)
   local seen = {}
   local result = {}

   for _, path in ipairs(paths) do
     local p = normalize_path(path)
     if not seen[p] then
       seen[p] = true
       table.insert(result, p)
     end
   end

   table.sort(result)
   return result
 end

 local function find_rust_projects(root_dir)
   if not root_dir then
     return {}
   end

   local root = normalize_path(root_dir)
   local matches = {}

   local patterns = {
     "/rust-project.json",
     "/out/rust-project.json",
     "/out/*/rust-project.json",
     "/build/rust-project.json",
     "/build/*/rust-project.json",
   }

   for _, pattern in ipairs(patterns) do
     vim.list_extend(
       matches,
       vim.fn.glob(root .. pattern, false, true)
     )
   end

   return dedupe_paths(matches)
 end


 local function find_project_root(fname)
   local util = require("lspconfig.util")
   local dir = vim.fs.dirname(fname)

   while dir do
     local projects = find_rust_projects(dir)
     if #projects > 0 then
       return dir
     end

     local parent = vim.fs.dirname(dir)
     if parent == dir then
       break
     end
     dir = parent
   end

   return util.root_pattern("Cargo.toml", "rust-project.json", ".git")(fname)
 end

 require("lspconfig").rust_analyzer.setup({
   cmd = { "rust-analyzer" },
   capabilities = require("cmp_nvim_lsp").default_capabilities(),

   root_dir = function(fname)
     return find_project_root(fname)
   end,

   on_new_config = function(new_config, root_dir)
     local projects = find_rust_projects(root_dir)

     if #projects > 0 then
       new_config.settings = new_config.settings or {}
       new_config.settings["rust-analyzer"] =
         new_config.settings["rust-analyzer"] or {}

       new_config.settings["rust-analyzer"].linkedProjects = projects
     end
   end,

   -- settings = {
   --   ["rust-analyzer"] = {},
   -- },

    settings = {
      ["rust-analyzer"] = {
        diagnostics = {
          enable = true,
        },
        checkOnSave = true,
      },
    },

 })



 local telescope = require("telescope")
 local builtin = require("telescope.builtin")


 local function filename_first(_, path)
   local normalized = path:gsub("\\", "/")
   local filename = vim.fn.fnamemodify(normalized, ":t")
   local dir = vim.fn.fnamemodify(normalized, ":h")
   if dir == "." or dir == "" then
     return filename
   end
   return filename .. "  " .. dir
 end


 local rg_excludes = {
   "--glob", "!out/**",
   "--glob", "!build/**",
   "--glob", "!target/**",
   "--glob", "!.git/**",
   "--glob", "!.vs/**",
   "--glob", "!.cipd/**",
 }

 local function with_excludes(base)
   local result = vim.deepcopy(base)
   vim.list_extend(result, rg_excludes)
   return result
 end

 telescope.setup({
   defaults = {
     layout_config = {
       prompt_position = "top",
     },
     sorting_strategy = "ascending",

     -- Show "filename path/to/dir" instead of very long path first.
     -- path_display = { "filename_first" },
     path_display = filename_first,

     -- Used by live_grep / grep_string.
     vimgrep_arguments = with_excludes({
       "rg",
       "--color=never",
       "--no-heading",
       "--with-filename",
       "--line-number",
       "--column",
       "--smart-case",
     }),
   },

   pickers = {
     find_files = {
       -- Used by <leader>fF below and by :Telescope find_files.
       find_command = with_excludes({
         "rg",
         "--files",
         "--hidden",
       }),
     },
   },
 })

local function project_files()
    local ok = pcall(builtin.git_files, {
        show_untracked = true,
        path_display = filename_first,
    })

    if not ok then
        builtin.find_files({
            hidden = true,
            path_display = filename_first,
        })
    end
end


local function raw_files()
    builtin.find_files({
        find_command = {
            "rg",
            "--files",
            "--hidden",
            "--no-ignore",
            "--no-ignore-parent",
        },
        path_display = filename_first,
    })
end


 vim.g.mapleader = " "

 vim.keymap.set('n', '<leader>e', function()
   vim.diagnostic.open_float(nil, {
     focusable = true,
     border = "rounded",       -- optional: makes popup prettier
     source = "always",        -- always show source (e.g., "clangd")
     prefix = "",              -- cleaner look
     scope = "line",           -- only show diagnostics for the current line
   })
 end, { desc = "Show diagnostics for line" })


 -- Setup nvim-cmp (completion engine)
 local cmp = require("cmp")

 cmp.setup({
   mapping = cmp.mapping.preset.insert({
     ['<C-Space>'] = cmp.mapping.complete(),        -- Trigger completion manually
     ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept completion
   }),
   sources = cmp.config.sources({
     { name = 'nvim_lsp' },  -- Use LSP as source for completions
   }),
 })

 vim.opt.termguicolors = true
 vim.opt.background = "dark"

 vim.api.nvim_set_hl(0, "Cursor", { bg = "#a7c080", fg = "#1e2326" })  -- light green on dark background
 -- vim.o.statusline = "%f [%{getcwd()}] %y %m %r %= %l:%c"



 -- LSP navigation
 vim.keymap.set("n", "gd", function()
   builtin.lsp_definitions({
     jump_type = "never",
     show_line = true,
     path_display = filename_first,
   })
 end, {
   desc = "LSP: definitions picker",
 })

 vim.keymap.set("n", "gD", vim.lsp.buf.definition, {
   desc = "LSP: raw go to definition",
 })

 vim.keymap.set("n", "grr", function()
   builtin.lsp_references({
     include_declaration = false,
     show_line = true,
   })
 end, {
   desc = "LSP: references",
 })

 vim.keymap.set("n", "gri", function()
   builtin.lsp_implementations({
     show_line = true,
   })
 end, {
   desc = "LSP: implementations",
 })

 vim.keymap.set("n", "grt", function()
   builtin.lsp_type_definitions({
     show_line = true,
   })
 end, {
   desc = "LSP: type definitions",
 })

 vim.keymap.set("n", "grc", function()
   builtin.lsp_incoming_calls({
     show_line = true,
   })
 end, {
   desc = "LSP: callers / incoming calls",
 })

 vim.keymap.set("n", "gro", function()
   builtin.lsp_outgoing_calls({
     show_line = true,
   })
 end, {
   desc = "LSP: callees / outgoing calls",
 })

 vim.keymap.set("n", "grn", vim.lsp.buf.rename, {
   desc = "LSP: rename symbol",
 })

 vim.keymap.set({ "n", "v" }, "gra", vim.lsp.buf.code_action, {
   desc = "LSP: code action",
 })

 vim.keymap.set("n", "K", vim.lsp.buf.hover, {
   desc = "LSP: hover",
 })



 vim.keymap.set("n", "<leader>ff", project_files, {
   desc = "Find project files",
 })


 vim.keymap.set("n", "<leader>fF", function()
   builtin.find_files({
     hidden = true,
     path_display = filename_first,
   })
 end, {
   desc = "Find files with explicit excludes",
 })


 vim.keymap.set("n", "<leader>fa", function()
   builtin.find_files({
     find_command = with_excludes({
       "rg",
       "--files",
       "--hidden",
       "--no-ignore",
     }),
     path_display = filename_first,
   })
 end, {
   desc = "Find all files except generated dirs",
 })

 vim.keymap.set("n", "<leader>fg", function()
   builtin.live_grep()
 end, {
   desc = "Live grep",
 })

 -- vim.keymap.set("n", "<leader>fb", builtin.buffers, {
 --   desc = "Find buffers",
 -- })


 vim.keymap.set("n", "<leader>fb", function()
   builtin.buffers({
     path_display = filename_first,
   })
 end, {
   desc = "Find buffers",
 })


 vim.keymap.set("n", "<leader>fh", builtin.help_tags, {
   desc = "Find help",
 })


 vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", {})
 vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", {})

 vim.keymap.set('n', '<A-j>', '5j', { noremap = true, silent = true }) -- Alt+j
 vim.keymap.set('n', '<A-k>', '5k', { noremap = true, silent = true }) -- Alt+k

vim.keymap.set("x", "p", '"_dP', {
    noremap = true,
    silent = true,
    desc = "Paste without overwriting clipboard",
})



 -- Force treesitter to use clang on Windows
 require("nvim-treesitter.install").compilers = { "cl" }

 require('nvim-treesitter.configs').setup {
   ensure_installed = { "c", "cpp", "rust", "lua", "vim", "bash", "cmake", "json" },
   highlight = { 
       enable = true
   },
   indent = { enable = false },
   incremental_selection = {
     enable = true,
     keymaps = {
       init_selection = "gss",         -- Start selection
       node_incremental = "gsn",       -- Expand to next node
       scope_incremental = "gsc",      -- Expand to scope
       node_decremental = "gsm",       -- Shrink
     },
   },
 }

 vim.opt.clipboard = "unnamedplus"

 vim.opt.tabstop = 4       -- how many columns a tab counts for
 vim.opt.shiftwidth = 4    -- how many spaces to use for each step of (auto)indent
 vim.opt.expandtab = true  -- convert tabs to spaces

 vim.opt.number = false

 vim.opt.autoindent = true
 vim.opt.smartindent = false
 vim.opt.cindent = false

 vim.keymap.set('n', 'H', '^', { noremap = true })  -- H = line start
 vim.keymap.set('n', 'L', 'g_', { noremap = true }) -- L = line end (last non-blank)



 vim.keymap.set("n", "<leader>q", function()
   -- Switch to next buffer, then delete previous
   vim.cmd("bnext | bd #")
 end, { desc = "Close buffer but keep window" })

 -- Stop rogue clangd clients with nil root_dir
 vim.api.nvim_create_autocmd("LspAttach", {
   callback = function(args)
     local client = vim.lsp.get_client_by_id(args.data.client_id)
     if client.name == "clangd" and client.config.root_dir == nil then
       vim.schedule(function()
         client.stop()
       end)
     end
   end,
 })

 vim.keymap.set('', '<CapsLock>', '<Nop>', { noremap = true })

 -- === minimal theme (cyan strings, green comments, blue numbers) ===
 -- Replace your previous apply_minimal_theme() with this version and :source %
 local function apply_minimal_theme()
   local C = {
     bg      = "#0b2424", -- dark teal chalkboard
     subtle  = "#142f2f",
     split   = "#112a2a",

     fg      = "#d0c890", -- parchment general text
     status  = "#c9b47a", -- beige statusline

     comment = "#6aa06a",   -- softer, sage green
     -- comment = "#66ff66",
     str     = "#80f0ff", -- cyan (strings)
     num     = "#80c0ff", -- bluish (numbers)
     kw      = "#e0f0ff", -- bluish-white (keywords/booleans/return)
   }

   vim.cmd("hi clear")
   vim.g.colors_name = "minimal_theme"

   local hi   = function(g, o) vim.api.nvim_set_hl(0, g, o) end
   local link = function(a, b) vim.api.nvim_set_hl(0, a, { link = b }) end

   -- UI
   hi("Normal",       { fg=C.fg, bg=C.bg })
   hi("NormalFloat",  { fg=C.fg, bg=C.subtle })
   hi("LineNr",       { fg=C.subtle, bg=C.bg })
   hi("CursorLineNr", { fg=C.fg, bg=C.bg })
   hi("CursorLine",   { bg=C.subtle })
   hi("VertSplit",    { fg=C.split, bg=C.bg })
   hi("WinSeparator", { fg=C.split, bg=C.bg })
   hi("SignColumn",   { bg=C.bg })
   -- hi("Visual",       { bg="#005f87" })
   -- hi("Visual", { bg="#1e40ff" })  -- try #0000ff if you want pure cobalt
   hi("Visual", { bg = "#0000ff" })
   hi("Search",       { fg=C.bg, bg=C.comment })
   hi("IncSearch",    { fg=C.bg, bg=C.comment })

   -- Base syntax
   hi("Comment",      { fg=C.comment, italic=false }) -- bright green
   hi("String",       { fg=C.str })                   -- cyan strings
   hi("Number",       { fg=C.num, bold=true })        -- bluish numbers
   hi("Float",        { fg=C.num, bold=true })
   hi("Identifier",   { fg=C.fg })
   hi("Function",     { fg=C.fg })
   hi("Operator",     { fg=C.fg })
   hi("Constant",     { fg=C.fg })
   hi("Type",         { fg=C.fg })

   -- Keywords / control flow / booleans → bluish-white
   hi("Keyword",      { fg=C.kw, bold=true })
   hi("Statement",    { fg=C.kw, bold=true })
   hi("Conditional",  { fg=C.kw, bold=true })
   hi("Repeat",       { fg=C.kw, bold=true })
   hi("Label",        { fg=C.kw, bold=true })
   hi("StorageClass", { fg=C.kw, bold=true })
   hi("Boolean",      { fg=C.kw, bold=true })
   hi("PreProc",      { fg=C.kw, bold=true }) -- e.g. #if/#import

   -- Treesitter links
   link("@comment",          "Comment")
   link("@string",           "String")
   link("@character",        "String")
   link("@number",           "Number")
   link("@float",            "Float")

   for _, g in ipairs({
     "@keyword","@keyword.function","@keyword.operator","@keyword.return",
     "@keyword.storage","@conditional","@repeat","@boolean","@preproc",
   }) do link(g, "Keyword") end

   for _, g in ipairs({
     "@variable","@variable.builtin","@function","@function.call","@method",
     "@field","@property","@parameter","@constructor","@namespace",
     "@include","@operator","@constant","@constant.builtin",
     "@type","@type.builtin","@type.definition","@type.qualifier",
     "@tag","@punctuation",
   }) do link(g, "Identifier") end

   -- Cursor + statusline
   hi("Cursor",       { bg="#a7c080", fg=C.bg })
   hi("StatusLine",   { fg=C.bg, bg=C.status })
   hi("StatusLineNC", { fg=C.bg, bg=C.subtle })
 end



 -- Disable LSP semantic tokens (they add purple/red otherwise)
 vim.api.nvim_create_autocmd("LspAttach", {
   callback = function(args)
     local client = vim.lsp.get_client_by_id(args.data.client_id)
     if client and client.server_capabilities.semanticTokensProvider then
       client.server_capabilities.semanticTokensProvider = nil
     end
   end,
 })


 vim.api.nvim_create_user_command("MinimalTheme", apply_minimal_theme, {})
 apply_minimal_theme()   

 -- Force preprocessor directives to minimal-style white
 vim.api.nvim_set_hl(0, "@keyword.directive", { fg = "#f8f8f2", bold = true })
 vim.api.nvim_set_hl(0, "@keyword.import",    { fg = "#f8f8f2", bold = true })

 -- Make clangd "unused include" diagnostic subtle instead of green-comment
 vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", { fg = "#f8f8f2", undercurl = true, sp = "#888888" })


 pcall(function()
   require("todo-comments.highlight").refresh()
 end)

 
