-- Neovim config — native LSP, Treesitter, modern stack.
-- Independent of the classic vim setup (~/.vimrc, ~/.coc.vim).
-- Migrated from coc.nvim. See docs/superpowers/specs/2026-07-22-neovim-native-lsp-design.md

--------------------------------------------------------------------
-- Leader (set before plugins so mappings register correctly)
--------------------------------------------------------------------
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

--------------------------------------------------------------------
-- Editor settings (ported from .vimrc)
--------------------------------------------------------------------
local opt = vim.opt
opt.background = "dark"
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.scrolloff = 20
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.swapfile = false
opt.wrap = false
opt.mouse = "a"
opt.signcolumn = "yes"
opt.updatetime = 300
opt.hlsearch = true
opt.incsearch = true
opt.backup = false
opt.writebackup = false

--------------------------------------------------------------------
-- Editing keymaps (ported verbatim from .vimrc)
--------------------------------------------------------------------
local map = vim.keymap.set

-- Window navigation with hjkl
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Make Y behave like D and C
map("n", "Y", "y$")

-- Keep cursor centered
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")
map("n", "J", "mzJ`z")

-- Undo break points
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", "!", "!<c-g>u")
map("i", "?", "?<c-g>u")

-- Move text (visual/insert/normal)
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true })
map("i", "<C-k>", "<esc>:m .-2<CR>==", { silent = true })
map("i", "<C-j>", "<esc>:m .+1<CR>==", { silent = true })
map("n", "<leader>j", ":m .+2<CR>==", { silent = true })
map("n", "<leader>k", ":m .-2<CR>==", { silent = true })

-- Toggle mouse (click/scroll vs terminal select)
local function toggle_mouse()
  if vim.o.mouse == "" then
    vim.o.mouse = "a"
    print("mouse on")
  else
    vim.o.mouse = ""
    print("mouse off")
  end
end
map("n", "mm", toggle_mouse)

--------------------------------------------------------------------
-- Bootstrap lazy.nvim
--------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

--------------------------------------------------------------------
-- Plugins
--------------------------------------------------------------------
require("lazy").setup({
  -- Theme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
      -- Transparent background to match old config's guibg=NONE
      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
      vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
    end,
  },

  -- Treesitter (replaces syntax on + polyglot)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "typescript", "tsx", "javascript", "json", "yaml",
        "dockerfile", "html", "css", "lua",
        "bash", "markdown",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  -- Statusline (replaces vim-airline)
  {
    "nvim-lualine/lualine.nvim",
    opts = { options = { theme = "tokyonight", globalstatus = true } },
  },

  -- Git signs (replaces vim-gitgutter)
  { "lewis6991/gitsigns.nvim", opts = {} },

  -- Git commands (same as vim)
  "tpope/vim-fugitive",

  -- Tab-size detection (same as vim)
  "tpope/vim-sleuth",

  -- Comments (replaces vim-commentary; gc/gcc)
  { "numToStr/Comment.nvim", opts = {} },

  -- File explorer (replaces NERDTree)
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view = { width = 50 },
      filters = { dotfiles = false }, -- show hidden, like NERDTreeShowHidden
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)
      map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { silent = true })
    end,
  },

  -- Fuzzy finder (replaces fzf.vim)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({})
      pcall(telescope.load_extension, "fzf")
      local builtin = require("telescope.builtin")
      -- <C-p> git files (replaces fzf GFiles), falls back to find_files if not a repo
      map("n", "<C-p>", function()
        local ok = pcall(builtin.git_files, { show_untracked = true })
        if not ok then builtin.find_files() end
      end, { silent = true })
      -- <leader>s live grep (replaces :Ag)
      map("n", "<leader>s", builtin.live_grep, { silent = true })
    end,
  },

  -- Completion (replaces coc pum)
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  -- Formatting (replaces coc-prettier)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        markdown = { "prettier" },
      },
    },
    config = function(_, opts)
      require("conform").setup(opts)
      -- <leader>f formats buffer (replaces coc :Format)
      map({ "n", "v" }, "<leader>f", function()
        require("conform").format({ async = true, lsp_fallback = true })
      end, { silent = true })
    end,
  },

  -- LSP: installer + config
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "ts_ls", "eslint", "jsonls", "yamlls",
          "dockerls", "emmet_ls",
        },
      })

      -- Shared capabilities (completion) for all servers
      local caps = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("*", { capabilities = caps })
      -- mason-lspconfig auto-enables installed servers on nvim 0.11+
    end,
  },
}, {
  -- lazy.nvim options
  install = { colorscheme = { "tokyonight-night" } },
  checker = { enabled = false },
})

--------------------------------------------------------------------
-- LSP keymaps + diagnostics (attach-time, native API)
--------------------------------------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local o = function(desc) return { buffer = bufnr, silent = true, desc = desc } end
    map("n", "gd", vim.lsp.buf.definition, o("goto definition"))
    map("n", "gy", vim.lsp.buf.type_definition, o("goto type definition"))
    map("n", "gi", vim.lsp.buf.implementation, o("goto implementation"))
    map("n", "gr", vim.lsp.buf.references, o("references"))
    map("n", "K", vim.lsp.buf.hover, o("hover"))
    map("n", "<leader>rn", vim.lsp.buf.rename, o("rename"))
    map("n", "<leader>ac", vim.lsp.buf.code_action, o("code action"))
    map("n", "<leader>qf", function()
      vim.lsp.buf.code_action({ apply = true })
    end, o("quickfix"))
  end,
})

-- Diagnostic navigation (replaces coc [g / ]g)
map("n", "[g", function() vim.diagnostic.jump({ count = -1, float = true }) end, { silent = true })
map("n", "]g", function() vim.diagnostic.jump({ count = 1, float = true }) end, { silent = true })

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
})
