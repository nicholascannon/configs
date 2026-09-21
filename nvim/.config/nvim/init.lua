-- Neovim config — native LSP, Treesitter, modern stack.
-- Independent of the classic vim setup (~/.vimrc, ~/.coc.vim).
-- Migrated from coc.nvim. See docs/superpowers/specs/2026-07-22-neovim-native-lsp-design.md

--------------------------------------------------------------------
-- Leader (set before plugins so mappings register correctly)
--------------------------------------------------------------------
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

--------------------------------------------------------------------
-- Machine-local overrides (gitignored, per-machine — not committed).
-- e.g. set `vim.g.enable_copilot = true` on machines with a Copilot seat.
-- Absent file is a no-op.
--------------------------------------------------------------------
pcall(dofile, vim.fn.stdpath("config") .. "/local.lua")

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
opt.wrap = true
opt.mouse = "a"
-- Mouse-drag enters Visual mode (not the terminal's native selection), so
-- macOS Cmd+C has nothing to copy. Use `y` after selecting instead — this
-- routes yanks/deletes to the system clipboard so `y` acts like a copy.
opt.clipboard = "unnamedplus"
opt.signcolumn = "yes"
opt.updatetime = 300
opt.hlsearch = true
opt.incsearch = true
opt.backup = false
opt.writebackup = false
opt.autoread = true

-- Files can change on disk outside nvim (e.g. Claude Code editing them
-- directly). Check on refocus rather than nvim's own write events. (Not
-- CursorHold: it refires on every idle pause and was resetting the cursor.)
vim.api.nvim_create_autocmd("FocusGained", {
  command = "checktime",
})

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

-- Mouse wheel bypasses 'scrollbind' (only keyboard scroll commands trigger
-- it), so diff/scrollbound windows (e.g. diffview) drift apart when
-- scrolling with the wheel. Route the wheel through <C-e>/<C-y>, which do
-- respect scrollbind, 1 line per notch.
map("n", "<ScrollWheelUp>", "<C-y>")
map("n", "<ScrollWheelDown>", "<C-e>")

-- Command-line spinner shown while waiting on the LLM. Returns a closer.
local function start_spinner(text)
  local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local frame = 0
  local timer = (vim.uv or vim.loop).new_timer()
  timer:start(0, 80, vim.schedule_wrap(function()
    frame = (frame % #frames) + 1
    vim.api.nvim_echo({ { frames[frame] .. " " .. text } }, false, {})
  end))
  return function()
    timer:stop()
    timer:close()
    vim.api.nvim_echo({ { "" } }, false, {})
  end
end

-- Generate a commit message from the staged diff (Copilot's "Commit" prompt)
-- and, after a manual confirm, commit with it. Requires staged changes.
local function copilot_commit()
  local close_spinner = start_spinner("Generating commit message...")
  local prompt = require("CopilotChat.config.prompts").Commit
  require("CopilotChat").ask(prompt.prompt, vim.tbl_extend("force", prompt, {
    headless = true,
    -- Fixed to a fast/cheap model regardless of whatever the interactive
    -- chat is set to — see `:CopilotChatModels` for the full name list.
    model = "gemini-3.8-flash",
    callback = function(response)
      vim.schedule(function()
        close_spinner()
        local content = response.content
        local message = vim.trim(content:match("```gitcommit\n(.-)\n```") or content)
        if message == "" then
          vim.notify("copilot_commit: no commit message generated", vim.log.levels.ERROR)
          return
        end
        if vim.fn.confirm("Commit with this message?\n\n" .. message, "&Yes\n&No", 2) ~= 1 then
          return
        end
        local result = vim.system({ "git", "commit", "-F", "-" }, { stdin = message }):wait()
        if result.code == 0 then
          vim.notify("Committed")
        else
          vim.notify("git commit failed: " .. result.stderr, vim.log.levels.ERROR)
        end
      end)
    end,
  }))
end

-- The repo's default branch: origin/HEAD, falling back to origin/main /
-- origin/master. Returns nil (after notifying) when none resolves.
local function default_branch()
  local base = vim.fn.system(
    "git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null")
    :gsub("%s+", ""):gsub("^origin/", "")
  if base == "" then
    for _, b in ipairs({ "main", "master" }) do
      if vim.fn.system("git rev-parse --quiet --verify origin/" .. b .. " 2>/dev/null") ~= "" then
        base = b
        break
      end
    end
  end
  if base == "" then
    vim.notify("default_branch: no origin/HEAD or origin/{main,master}", vim.log.levels.ERROR)
    return nil
  end
  return base
end

-- unified.nvim takes a single ref, so resolve the merge-base ourselves to show
-- a 3-dot diff (current branch vs where it forked from the default branch).
local function unified_vs_base()
  local base = default_branch()
  if not base then return end
  local merge_base = vim.trim(vim.fn.system("git merge-base " .. base .. " HEAD"))
  if vim.v.shell_error ~= 0 then
    vim.notify("unified_vs_base: " .. merge_base, vim.log.levels.ERROR)
    return
  end
  vim.cmd("Unified " .. merge_base)
end

-- unified.nvim's own tree `q` closes only the tree window: diff extmarks stay in
-- the file buffers (visible in every tab showing them) and the tab opened by
-- `tab = true` stays open. reset clears the extmarks but not the tab, so close
-- the tab that holds the tree as well.
local function close_unified()
  local tree_win = require("unified.state").file_tree_win
  local tab = tree_win and vim.api.nvim_win_is_valid(tree_win)
    and vim.api.nvim_win_get_tabpage(tree_win)
  require("unified.command").reset()
  if tab and #vim.api.nvim_list_tabpages() > 1 and vim.api.nvim_tabpage_is_valid(tab) then
    vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(tab))
  end
end

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
-- Theme — native colorscheme (colors/aero.lua), not a plugin. Ported from
-- the Zed theme at zed/.config/zed/themes/Aero.json; keep both in sync
-- manually. Set before lazy.setup so lualine's "auto" theme (below) reads it.
vim.cmd.colorscheme("aero")
-- Transparent background to match old config's guibg=NONE
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })

require("lazy").setup({
  -- Treesitter (replaces syntax on + polyglot).
  -- Uses the `main` branch — the only branch compatible with Neovim 0.12.
  -- (master is archived and crashes on 0.12: match[id] became a node list,
  --  breaking its query_predicates -> "attempt to call method 'range'".)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- NOTE: markdown/markdown_inline are intentionally omitted — Neovim
      -- bundles those parsers, and nvim-treesitter's installer currently
      -- fails to fetch the markdown grammar (its archive uses a "split_parser"
      -- branch dir but the installer expects "-master"). Bundled parser +
      -- these queries highlight markdown fine without installing.
      require("nvim-treesitter").install({
        "typescript", "tsx", "javascript", "json", "yaml",
        "dockerfile", "html", "css", "lua", "bash", "prisma",
      })
      -- Highlighting/indent are enabled per-buffer (main-branch model).
      -- Broad autocmd: start treesitter for any buffer whose language has a
      -- parser installed; silently no-op otherwise.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- In-buffer markdown rendering (headers, bold, lists, code blocks) — no
  -- browser needed. \mr toggles it on the current buffer.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown render" },
    },
    opts = {
      -- Default reveals raw markdown on the cursor's line and re-renders it
      -- on every cursor move, which reads as jank while scrolling. Keep
      -- everything rendered, including the current line.
      anti_conceal = { enabled = false },
      -- Default excludes visual modes ("n", "c", "t" only), so click-and-drag
      -- selection dropped the whole buffer to raw markdown mid-drag. Keep
      -- rendering through visual/visual-line/visual-block; still raw in
      -- insert, since editing needs the actual markdown syntax.
      render_modes = { "n", "c", "t", "v", "V", "\22" },
    },
  },

  -- Statusline (replaces vim-airline)
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      local theme = require("lualine.themes.auto")
      -- "auto" derives normal mode from Pmenu (dim gray, barely visible) and
      -- command mode from Identifier (near-white, reads much better). Swap.
      theme.normal, theme.command = theme.command, theme.normal
      -- "auto" derives visual mode from Special, which aero.lua points at
      -- the same green as String — colliding with insert mode. Pull it from
      -- Keyword (purple) instead, an Aero color no other mode uses.
      local keyword = vim.api.nvim_get_hl(0, { name = "Keyword", link = false }).fg
      if keyword then
        local hex = string.format("#%06x", keyword)
        theme.visual.a.bg = hex
        theme.visual.b.fg = hex
      end
      require("lualine").setup({ options = { theme = theme, globalstatus = true } })
    end,
  },

  -- Git signs (replaces vim-gitgutter)
  { "lewis6991/gitsigns.nvim", opts = { current_line_blame = true } },

-- Git commands (same as vim)
  "tpope/vim-fugitive",

  -- Unified (GitHub-style) diff review. \dv uncommitted changes vs HEAD,
  -- \db current branch vs its default-branch base, \dh commit picker (pick a
  -- base commit and diff against it — not per-file history, unified.nvim has
  -- no equivalent to diffview's FileHistory).
  {
    "axkirillov/unified.nvim",
    keys = {
      { "<leader>dv", "<cmd>Unified HEAD<cr>", desc = "Unified: uncommitted" },
      { "<leader>db", unified_vs_base, desc = "Unified: branch vs base" },
      { "<leader>dh", "<cmd>Unified<cr>", desc = "Unified: commit picker" },
      { "<leader>dq", close_unified, desc = "Close diff view" },
    },
    opts = {
      tab = true,
      file_tree = { focus = true, width = 45 }, -- width default 30
    },
    init = function()
      -- The file tree only opens files with `l`; Enter falls through to the
      -- default cursor-down and leaves the file window empty.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "unified_tree",
        callback = function(args)
          map("n", "<CR>", function()
            require("unified.file_tree.actions").toggle_node()
          end, { buffer = args.buf, silent = true })
          map("n", "q", close_unified, { buffer = args.buf, silent = true, nowait = true })
        end,
      })
    end,
  },

  -- GitHub Copilot (inline ghost text). Gated on vim.g.enable_copilot, set in
  -- the gitignored local.lua — so it only loads on machines with a seat.
  -- <Tab> accepts the suggestion (cmp menu is on arrow keys). First use needs
  -- `:Copilot auth` (device login; uses the Copilot seat, no API key).
  {
    "zbirenbaum/copilot.lua",
    cond = function() return vim.g.enable_copilot == true end,
    event = "InsertEnter",
    cmd = "Copilot",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          dismiss = "<C-]>",
          next = "<M-]>",
          prev = "<M-[>",
        },
      },
      panel = { enabled = false },
      filetypes = { ["*"] = true },
    },
  },

  -- Copilot Chat: same seat as copilot.lua above. \gc generates a commit
  -- message from the staged diff (see copilot_commit above) and, after a
  -- manual confirm, commits with it — same UX as Zed's commit-message button.
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    cond = function() return vim.g.enable_copilot == true end,
    branch = "main",
    dependencies = { "zbirenbaum/copilot.lua", "nvim-lua/plenary.nvim" },
    cmd = "CopilotChat",
    keys = {
      { "<leader>gc", copilot_commit, desc = "Copilot: generate + confirm commit" },
    },
    opts = {},
  },

  -- GitHub PR diffs. Uses the authed gh CLI. Lazy-loads on :Octo / the keymaps.
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = { picker = "telescope", enable_builtin = true },
    keys = {
      -- <leader> is "\": \op lists PRs, \od opens the diff view of the open PR
      { "<leader>op", "<cmd>Octo pr list<cr>", desc = "GitHub: list PRs" },
      { "<leader>od", "<cmd>Octo pr diff<cr>", desc = "GitHub: PR diff view" },
    },
  },

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
      -- Show everything: dotfiles + gitignored (so superpowers docs under a
      -- gitignored docs/ are visible). git status icons stay on.
      filters = { dotfiles = false, git_ignored = false },
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)
      map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { silent = true })
    end,
  },

  -- Fuzzy finder (replaces fzf.vim)
  {
    "nvim-telescope/telescope.nvim",
    -- Track master, not the 0.1.x tag: 0.1.x's previewer calls nvim-treesitter
    -- master APIs (ft_to_lang) removed in the main-branch rewrite. master uses
    -- native vim.treesitter instead.
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")

      -- Gitignored dirs that should still be searchable (superpowers plans/docs
      -- live under gitignored paths). Everything else respects .gitignore, so
      -- node_modules and generated build output stay out — important in big
      -- monorepos where --no-ignore pulls in tens of thousands of artifacts.
      local doc_dirs = { "docs", ".superpowers", "specs", "plans", ".claude" }

      -- find_files backend: pass 1 lists the tree respecting .gitignore; pass 2
      -- re-lists the doc dirs with --no-ignore; awk dedupes (order-preserving).
      local find_command = {
        "sh", "-c",
        "{ rg --files --hidden --glob '!.git/**'; "
          .. "for d in " .. table.concat(doc_dirs, " ") .. "; do "
          .. "[ -d \"$d\" ] && rg --files --hidden --no-ignore --glob '!.git/**' -- \"$d\"; "
          .. "done; } | awk '!seen[$0]++'",
      }

      telescope.setup({
        pickers = {
          find_files = { find_command = find_command },
        },
      })
      pcall(telescope.load_extension, "fzf")
      local builtin = require("telescope.builtin")
      -- <C-p> file finder (replaces fzf GFiles): gitignore-respecting + doc dirs.
      map("n", "<C-p>", builtin.find_files, { silent = true })
      -- <leader>s live grep (replaces :Ag). Whole tree respecting .gitignore,
      -- plus the doc dirs so their content is searchable too.
      map("n", "<leader>s", function()
        local dirs = { "." }
        for _, d in ipairs(doc_dirs) do
          if vim.fn.isdirectory(d) == 1 then dirs[#dirs + 1] = d end
        end
        builtin.live_grep({
          search_dirs = dirs,
          additional_args = { "--hidden" },
        })
      end, { silent = true })
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
        -- Navigate the LSP menu with arrows; <CR> confirms. <Tab> is left
        -- unbound here so Copilot (when enabled) can use it to accept ghost text.
        mapping = cmp.mapping.preset.insert({
          ["<Down>"] = cmp.mapping.select_next_item(),
          ["<Up>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
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
          "dockerls", "emmet_ls", "prismals",
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
  install = { colorscheme = { "aero" } },
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
