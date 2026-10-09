-- Neovim config — native LSP, Treesitter, modern stack.
-- Independent of the classic vim setup (~/.vimrc, ~/.coc.vim).
-- Migrated from coc.nvim.

--------------------------------------------------------------------
-- Leader (set before plugins so mappings register correctly)
--------------------------------------------------------------------
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

--------------------------------------------------------------------
-- Machine-local overrides (gitignored, per-machine — not committed).
-- Absent file is a no-op.
--------------------------------------------------------------------
pcall(dofile, vim.fn.stdpath("config") .. "/local.lua")

--------------------------------------------------------------------
-- Editor settings (ported from .vimrc)
--------------------------------------------------------------------
local opt = vim.opt
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.swapfile = false
opt.undofile = true
opt.autoread = true
opt.mouse = "a"
-- Mouse-drag enters Visual mode (not the terminal's native selection), so
-- macOS Cmd+C has nothing to copy. Use `y` after selecting instead — this
-- routes yanks/deletes to the system clipboard so `y` acts like a copy.
opt.clipboard = "unnamedplus"
opt.signcolumn = "yes"
opt.updatetime = 300
opt.writebackup = false
opt.title = true
opt.titlestring = "nvim %{fnamemodify(getcwd(), ':t')}"

-- Files can change on disk outside nvim (e.g. Claude Code editing them
-- directly). Check on refocus, buffer switch and leaving a terminal rather
-- than nvim's own write events. (Not CursorHold: it refires on every idle
-- pause and was resetting the cursor.)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
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
map("n", "<leader>j", ":m .+1<CR>==", { silent = true })
map("n", "<leader>k", ":m .-2<CR>==", { silent = true })

-- Single <Esc> must reach TUIs in the terminal (Claude Code, fzf), so leaving
-- terminal mode needs a double tap.
map("t", "<Esc><Esc>", [[<C-\><C-n>]])

local tab_snapshot, closed_tabs = {}, {}

-- TabClosed fires after the tab is gone, so the closed tab's file has to come
-- from a snapshot taken while it still existed.
local function snapshot_tabs()
	tab_snapshot = {}
	for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
		tab_snapshot[i] = vim.api.nvim_buf_get_name(buf)
	end
end

vim.api.nvim_create_autocmd({ "BufEnter", "TabEnter", "TabNew" }, { callback = snapshot_tabs })
vim.api.nvim_create_autocmd("TabClosed", {
	callback = function(ev)
		local path = tab_snapshot[tonumber(ev.file)]
		if path and path ~= "" then
			table.insert(closed_tabs, path)
		end
		snapshot_tabs()
	end,
})

local function reopen_closed_tab()
	local path = table.remove(closed_tabs)
	if not path then
		return vim.notify("No closed tab to reopen")
	end
	vim.cmd.tabnew(vim.fn.fnameescape(path))
end

map("n", "<leader>t", "<cmd>tabnew<CR>", { desc = "new tab" })
map("n", "<leader>T", reopen_closed_tab, { desc = "reopen closed tab" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "close window/tab" })
map("n", [[<C-\>]], "<cmd>tab terminal<CR><cmd>startinsert<CR>", { desc = "terminal in new tab" })

for n = 1, 9 do
	map("n", "<leader>" .. n, n .. "gt", { desc = "go to tab " .. n })
end

local function yank_reference(first, last)
	local ref = vim.fn.expand("%:.") .. ":" .. first
	if last ~= first then
		ref = ref .. "-" .. last
	end
	vim.fn.setreg("+", ref)
	vim.notify("Yanked " .. ref)
end

map("n", "<leader>yr", function()
	local line = vim.fn.line(".")
	yank_reference(line, line)
end, { desc = "yank path:line reference" })

map("x", "<leader>yr", function()
	local a, b = vim.fn.line("v"), vim.fn.line(".")
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	yank_reference(math.min(a, b), math.max(a, b))
end, { desc = "yank path:start-end reference" })

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
-- respect scrollbind, 1 line per notch. Run in the window under the pointer
-- (not the focused one) to match the default wheel behaviour.
local function wheel_scroll(key)
	return function()
		local winid = vim.fn.getmousepos().winid
		if winid == 0 or not vim.api.nvim_win_is_valid(winid) then
			winid = vim.api.nvim_get_current_win()
		end
		vim.api.nvim_win_call(winid, function()
			vim.cmd("normal! " .. vim.keycode(key))
		end)
	end
end
map("n", "<ScrollWheelUp>", wheel_scroll("<C-y>"))
map("n", "<ScrollWheelDown>", wheel_scroll("<C-e>"))

-- Default is hor:6, which is far too fast for trackpad horizontal scrolling.
opt.mousescroll = "ver:1,hor:1"

-- Command-line spinner shown while waiting on the LLM. Returns a closer.
local function start_spinner(text)
	local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
	local frame = 0
	local timer = vim.uv.new_timer()
	timer:start(
		0,
		80,
		vim.schedule_wrap(function()
			frame = (frame % #frames) + 1
			vim.api.nvim_echo({ { frames[frame] .. " " .. text } }, false, {})
		end)
	)
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
	require("CopilotChat").ask(
		prompt.prompt,
		vim.tbl_extend("force", prompt, {
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
		})
	)
end

vim.api.nvim_create_user_command("GenCommit", copilot_commit, {
	desc = "Copilot: generate + confirm commit",
})

-- The repo's default branch: origin/HEAD, falling back to origin/main /
-- origin/master. Returns nil (after notifying) when none resolves.
local function default_branch()
	local base = vim.fn
		.system("git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null")
		:gsub("%s+", "")
		:gsub("^origin/", "")
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

-- Everything the branch changes, committed or not: merge-base with the origin
-- default branch vs the working tree. Ending at the working tree keeps the
-- real file buffer in the diff, so LSP and edits work while reviewing.
local function codediff_vs_base()
	local base = default_branch()
	if base then
		vim.cmd("CodeDiff origin/" .. base .. "...")
	end
end

-- mini.map integration for CodeDiff buffers, which gitsigns never attaches to.
-- Reads CodeDiff's own extmarks: inserted lines are green, removed lines red,
-- and lines carrying both yellow.
local function codediff_minimap_lines()
	local buf = require("mini.map").current.buf_data.source
	if not vim.api.nvim_buf_is_valid(buf) then
		return {}
	end

	local kinds = {}
	local function mark(line, kind)
		kinds[line] = kinds[line] and kinds[line] ~= kind and "change" or kind
	end

	for _, name in ipairs({ "codediff-highlight", "codediff-inline" }) do
		local ns = vim.api.nvim_get_namespaces()[name]
		if ns then
			local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
			for _, m in ipairs(marks) do
				local row, d = m[2], m[4]
				if d.hl_group == "CodeDiffLineInsert" then
					for r = row, (d.end_row or row + 1) - 1 do
						mark(r + 1, "add")
					end
				elseif d.hl_group == "CodeDiffLineDelete" then
					for r = row, (d.end_row or row + 1) - 1 do
						mark(r + 1, "delete")
					end
				elseif d.virt_lines then
					-- Inline layout: removed lines are virtual, anchored to the line below.
					mark(row + 1, "delete")
				end
			end
		end
	end

	local groups = { add = "GitSignsAdd", change = "GitSignsChange", delete = "GitSignsDelete" }
	local res = {}
	for line, kind in pairs(kinds) do
		table.insert(res, { line = line, hl_group = groups[kind] })
	end
	return res
end

--------------------------------------------------------------------
-- Bootstrap lazy.nvim
--------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
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
				"typescript",
				"tsx",
				"javascript",
				"json",
				"yaml",
				"dockerfile",
				"html",
				"css",
				"lua",
				"bash",
				"prisma",
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

	-- Pins the enclosing function/class header at the top of the window.
	{
		"nvim-treesitter/nvim-treesitter-context",
		event = "VeryLazy",
		opts = { max_lines = 3 },
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
			-- LSP hover/diagnostic floats are nofile markdown buffers, usually one
			-- big code block. Its darker code background and language header row
			-- clash with NormalFloat; with no header, the fences are concealed.
			overrides = {
				buftype = { nofile = { code = { disable_background = true, language = false } } },
			},
		},
	},

	-- Statusline (replaces vim-airline)
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			-- Statusline highlights can't mix an icon fg with the tab's bg, so define
			-- a group per (icon color, tab bg) pair and switch back after the icon.
			local defined_icon_groups = {}
			-- A colorscheme change wipes custom groups, so they must be redefined.
			vim.api.nvim_create_autocmd("ColorScheme", {
				callback = function()
					defined_icon_groups = {}
				end,
			})
			local function colored_icon(icon, color, tab)
				local tab_hl = require("lualine.highlight").component_format_highlight(
					tab.highlights[tab.current and "active" or "inactive"]
				)
				local bg = vim.api.nvim_get_hl(0, { name = tab_hl:match("%%#(.-)#"), link = false }).bg
				local group = ("LualineTabIcon_%s_%s"):format(color:sub(2), bg or "none")
				if not defined_icon_groups[group] then
					vim.api.nvim_set_hl(0, group, { fg = color, bg = bg })
					defined_icon_groups[group] = true
				end
				return "%#" .. group .. "#" .. icon .. tab_hl
			end
			local function tab_label(label, tab)
				local buf = vim.fn.tabpagebuflist(tab.tabnr)[vim.fn.tabpagewinnr(tab.tabnr)]
				local path = vim.api.nvim_buf_get_name(buf)
				local name = vim.fn.fnamemodify(path, ":t")
				local devicons = require("nvim-web-devicons")
				local icon, color = devicons.get_icon_color(name, vim.fn.fnamemodify(name, ":e"), { default = true })
				return colored_icon(icon, color, tab) .. " " .. label
			end
			-- Branch-wide diff stat, cached and refreshed asynchronously so the
			-- statusline redraw never waits on git.
			local branch_stat = { files = "", added = "", removed = "" }
			local stat_running = false
			local last_stat_run = 0
			-- origin/HEAD resolves to origin/main or origin/master per repo; the
			-- merge-base keeps commits that landed on main after branching out of the count.
			local stat_script = [[
				base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD || echo origin/main)
				mb=$(git merge-base "$base" HEAD 2>/dev/null) || exit 0
				git diff --shortstat "$mb"
			]]
			-- Resolved here because vimscript functions can't run in the vim.system callback.
			local file_icon = vim.fn.nr2char(0xf15b)
			local function parse_stat(out)
				local files = out:match("(%d+) files? changed")
				if not files then
					return { files = "", added = "", removed = "" }
				end
				return {
					files = file_icon .. " " .. files,
					added = "+" .. (out:match("(%d+) insertion") or "0"),
					removed = "-" .. (out:match("(%d+) deletion") or "0"),
				}
			end
			local function refresh_branch_stat()
				-- Throttled so rapid buffer switching doesn't spawn a git process each time.
				if stat_running or vim.uv.now() - last_stat_run < 2000 then
					return
				end
				stat_running = true
				last_stat_run = vim.uv.now()
				vim.system({ "sh", "-c", stat_script }, { cwd = vim.fn.getcwd(), text = true }, function(res)
					stat_running = false
					local stat = parse_stat(res.stdout or "")
					vim.schedule(function()
						if not vim.deep_equal(stat, branch_stat) then
							branch_stat = stat
							require("lualine").refresh()
						end
					end)
				end)
			end
			vim.api.nvim_create_autocmd(
				{ "VimEnter", "BufEnter", "BufWritePost", "FocusGained", "DirChanged", "TermClose" },
				{ callback = refresh_branch_stat }
			)
			local function stat_component(field, hl_group)
				return {
					function()
						return branch_stat[field]
					end,
					cond = function()
						return branch_stat[field] ~= ""
					end,
					color = hl_group and function()
						local fg = vim.api.nvim_get_hl(0, { name = hl_group, link = false }).fg
						return { fg = fg and ("#%06x"):format(fg) }
					end,
					separator = { left = "", right = "" },
					padding = { left = 0, right = 1 },
				}
			end
			require("lualine").setup({
				options = {
					theme = "aero",
					globalstatus = true,
					always_show_tabline = false,
				},
				-- path = 1: relative to cwd, so the statusline shows where a file
				-- lives without the full absolute path eating the whole bar.
				sections = {
					lualine_c = { { "filename", path = 1 } },
					lualine_b = { "branch" },
					lualine_x = {
						stat_component("files"),
						stat_component("added", "GitSignsAdd"),
						stat_component("removed", "GitSignsDelete"),
						"diagnostics",
						"encoding",
						"fileformat",
						"filetype",
					},
				},
				tabline = {
					lualine_a = {
						{
							"tabs",
							mode = 2,
							path = 1,
							section_separators = { left = "", right = "" },
							component_separators = { left = "", right = "" },
							fmt = tab_label,
							-- lualine counts the icon's highlight markup (~70 chars per tab) as
							-- visible width, so widen the limit to match.
							max_length = function()
								return vim.o.columns + vim.fn.tabpagenr("$") * 70
							end,
							tab_max_length = 30,
						},
					},
				},
			})
		end,
	},

	-- Git signs (replaces vim-gitgutter)
	{ "lewis6991/gitsigns.nvim", opts = { current_line_blame = true } },

	-- Git commands (same as vim)
	"tpope/vim-fugitive",

	-- VSCode-style diff review in its own tab, live-refreshing as an agent
	-- edits. \db branch + uncommitted vs origin default branch, \dv uncommitted
	-- vs HEAD, \dl latest commit only (read-only snapshots, no LSP), \dh commit
	-- history. In the view: t toggles inline/split, ]c/[c hunks, ]f/[f files,
	-- gf opens the file in the previous tab, q closes, g? lists keymaps.
	{
		"esmuellert/codediff.nvim",
		cmd = "CodeDiff",
		keys = {
			{ "<leader>db", codediff_vs_base, desc = "CodeDiff: branch vs base" },
			{ "<leader>dv", "<cmd>CodeDiff<cr>", desc = "CodeDiff: uncommitted" },
			{ "<leader>dl", "<cmd>CodeDiff HEAD~1 HEAD<cr>", desc = "CodeDiff: latest commit" },
			{ "<leader>dh", "<cmd>CodeDiff history<cr>", desc = "CodeDiff: commit history" },
		},
		opts = {
			highlights = { char_insert = "DiffTextAdd", char_delete = "DiffTextDelete" },
			diff = {
				layout = "inline",
				highlight_added_deleted_files = true,
				-- Split view only: the inline renderer clears gutter signs.
				gutter_signs = { insert_text = "▎", delete_text = "▎" },
			},
			explorer = { view_mode = "tree", width = 30 },
		},
		config = function(_, opts)
			require("codediff").setup(opts)
			-- nvim-tree's tab.sync.open re-opens the tree on every TabEnter, which
			-- crowds out the CodeDiff explorer. These autocmds are created after
			-- nvim-tree's, so their scheduled callbacks run after its scheduled open.
			local codediff_tabs = {}
			local function hide_nvim_tree(tab)
				if not vim.api.nvim_tabpage_is_valid(tab) then
					return
				end
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
					if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
						vim.api.nvim_win_close(win, false)
					end
				end
			end
			-- CodeDiff's own <2-LeftMouse> handler skips folders; <CR> toggles them.
			local function map_explorer_double_click(tab)
				if not vim.api.nvim_tabpage_is_valid(tab) then
					return
				end
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
					local buf = vim.api.nvim_win_get_buf(win)
					if vim.bo[buf].filetype == "codediff-explorer" then
						vim.keymap.set(
							"n",
							"<2-LeftMouse>",
							"<CR>",
							{ buffer = buf, remap = true, nowait = true, silent = true }
						)
					end
				end
			end
			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeDiffOpen",
				callback = function(args)
					codediff_tabs[args.data.tabpage] = true
					vim.schedule(function()
						hide_nvim_tree(args.data.tabpage)
						map_explorer_double_click(args.data.tabpage)
					end)
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeDiffClose",
				callback = function(args)
					codediff_tabs[args.data.tabpage] = nil
				end,
			})
			-- layout.arrange() re-pins the explorer to config.options.explorer.width
			-- on every file switch, discarding manual resizes. Persist them there.
			vim.api.nvim_create_autocmd("WinResized", {
				callback = function()
					for _, win in ipairs(vim.v.event.windows) do
						if
							vim.api.nvim_win_is_valid(win)
							and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "codediff-explorer"
						then
							local explorer = require("codediff.config").options.explorer
							if explorer.position ~= "bottom" then
								explorer.width = vim.api.nvim_win_get_width(win)
							end
						end
					end
				end,
			})
			vim.api.nvim_create_autocmd("TabEnter", {
				callback = function()
					local tab = vim.api.nvim_get_current_tabpage()
					if codediff_tabs[tab] then
						vim.schedule(function()
							hide_nvim_tree(tab)
						end)
					end
				end,
			})
		end,
	},

	-- Minimap of the whole buffer with a viewport indicator. Open by default
	-- (it follows the focused window, including CodeDiff panes); \mm toggles it.
	{
		"echasnovski/mini.map",
		version = false,
		event = "VeryLazy",
		keys = {
			{
				"<leader>mm",
				function()
					require("mini.map").toggle()
				end,
				desc = "Toggle minimap",
			},
		},
		init = function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeDiffOpen",
				callback = function()
					vim.schedule(function()
						require("mini.map").open()
					end)
				end,
			})
			-- CodeDiff paints its extmarks after these events fire.
			vim.api.nvim_create_autocmd("User", {
				pattern = { "CodeDiffOpen", "CodeDiffFileSelect" },
				callback = function()
					vim.defer_fn(function()
						local minimap = package.loaded["mini.map"]
						if minimap and minimap.current.win_data[vim.api.nvim_get_current_tabpage()] then
							minimap.refresh({}, { integrations = true, lines = false, scrollbar = false })
						end
					end, 100)
				end,
			})
		end,
		config = function()
			local minimap = require("mini.map")
			minimap.setup({
				integrations = { minimap.gen_integration.gitsigns(), codediff_minimap_lines },
				symbols = {
					encode = minimap.gen_encode_symbols.dot("4x2"),
					scroll_line = "▐",
					scroll_view = "┃",
				},
				window = { width = 10, winblend = 35, show_integration_count = false },
			})

			local function style_minimap()
				local function fg(group)
					return vim.api.nvim_get_hl(0, { name = group, link = false }).fg
				end
				local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
				vim.api.nvim_set_hl(0, "MiniMapNormal", { fg = fg("LineNr"), bg = bg })
				vim.api.nvim_set_hl(0, "MiniMapSymbolView", { fg = fg("Comment"), bg = bg })
				vim.api.nvim_set_hl(0, "MiniMapSymbolLine", { fg = fg("Function"), bg = bg })
				vim.api.nvim_set_hl(0, "MiniMapSymbolCount", { fg = fg("Comment"), bg = bg })
			end
			style_minimap()
			vim.api.nvim_create_autocmd("ColorScheme", { callback = style_minimap })
			minimap.open()
		end,
	},

	-- GitHub Copilot (inline ghost text). <Tab> accepts the suggestion (cmp
	-- menu is on arrow keys). First use needs `:Copilot auth` (device login;
	-- uses the Copilot seat, no API key).
	{
		"zbirenbaum/copilot.lua",
		event = "InsertEnter",
		cmd = "Copilot",
		opts = {
			suggestion = {
				enabled = true,
				auto_trigger = true,
				-- Default true: <Tab> with no suggestion showing requests one instead
				-- of inserting a tab, so <Tab> is swallowed whenever Copilot is idle.
				trigger_on_accept = false,
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
		branch = "main",
		dependencies = { "zbirenbaum/copilot.lua", "nvim-lua/plenary.nvim" },
		cmd = "CopilotChat",
		keys = {
			{ "<leader>gc", copilot_commit, desc = "Copilot: generate + confirm commit" },
		},
		opts = {},
	},

	-- Tab-size detection (same as vim)
	"tpope/vim-sleuth",

	-- File explorer (replaces NERDTree)
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			-- Show everything: dotfiles + gitignored (so superpowers docs under a
			-- gitignored docs/ are visible). git status icons stay on.
			filters = { dotfiles = false, git_ignored = false },
			update_focused_file = { enable = true },
			-- Tree persists across tabs like a VSCode/Zed sidebar instead of being
			-- scoped to the tab it was opened in.
			tab = { sync = { open = true, close = true } },
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
				"sh",
				"-c",
				"{ rg --files --hidden --glob '!.git/**'; "
					.. "for d in "
					.. table.concat(doc_dirs, " ")
					.. "; do "
					.. '[ -d "$d" ] && rg --files --hidden --no-ignore --glob \'!.git/**\' -- "$d"; '
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
					if vim.fn.isdirectory(d) == 1 then
						dirs[#dirs + 1] = d
					end
				end
				builtin.live_grep({
					search_dirs = dirs,
					additional_args = { "--hidden" },
				})
			end, { silent = true })
		end,
	},

	-- Completion (replaces coc pum). Pinned to v1: v2 is pre-release with
	-- breaking changes. v1 releases ship a prebuilt fuzzy-matcher binary, so no
	-- Rust toolchain is needed.
	{
		"saghen/blink.cmp",
		version = "1.*",
		opts = {
			-- Navigate the LSP menu with arrows; <CR> confirms only an explicitly
			-- selected item. <Tab> is left unbound so Copilot (when enabled) can use
			-- it to accept ghost text.
			keymap = {
				preset = "none",
				["<Down>"] = { "select_next", "fallback" },
				["<Up>"] = { "select_prev", "fallback" },
				["<C-n>"] = { "select_next", "fallback" },
				["<C-p>"] = { "select_prev", "fallback" },
				["<C-y>"] = { "select_and_accept", "fallback" },
				["<C-e>"] = { "cancel", "fallback" },
				["<CR>"] = { "accept", "fallback" },
			},
			completion = { list = { selection = { preselect = false } } },
			sources = { default = { "lsp", "path", "buffer" } },
			cmdline = { enabled = false },
		},
	},

	-- Formatting (replaces coc-prettier)
	{
		"stevearc/conform.nvim",
		opts = {
			-- biome only runs if the project actually has a biome config (checked
			-- below); otherwise conform falls through to prettier. ESLint's own
			-- fixAll runs separately through its language server (see LspAttach).
			formatters_by_ft = {
				javascript = { "biome", "prettier", stop_after_first = true },
				typescript = { "biome", "prettier", stop_after_first = true },
				javascriptreact = { "biome", "prettier", stop_after_first = true },
				typescriptreact = { "biome", "prettier", stop_after_first = true },
				json = { "biome", "prettier", stop_after_first = true },
				yaml = { "prettier" },
				html = { "prettier" },
				css = { "prettier" },
				markdown = { "prettier" },
				go = { "goimports" },
			},
			formatters = {
				biome = {
					condition = function(_, ctx)
						return vim.fs.find({ "biome.json", "biome.jsonc" }, { path = ctx.filename, upward = true })[1]
							~= nil
					end,
				},
			},
			-- Falls back to LSP formatting for filetypes with no formatter above.
			format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
		},
		config = function(_, opts)
			require("conform").setup(opts)
			-- <leader>f formats buffer (replaces coc :Format). Mirrors the
			-- format-on-save order: conform's formatter first, then ESLint's own
			-- fixAll — conform.format() only runs the formatters above, it doesn't
			-- know about LspEslintFixAll.
			map({ "n", "v" }, "<leader>f", function()
				require("conform").format({ async = true, lsp_format = "fallback" }, function()
					if #vim.lsp.get_clients({ bufnr = 0, name = "eslint" }) > 0 then
						vim.cmd("LspEslintFixAll")
					end
				end)
			end, { silent = true })
		end,
	},

	-- LSP: installer + config
	{
		"mason-org/mason.nvim",
		opts = {},
	},
	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = {
			"mason-org/mason.nvim",
			"neovim/nvim-lspconfig",
		},
		-- mason-lspconfig auto-enables installed servers on nvim 0.11+, and
		-- blink.cmp registers its completion capabilities via vim.lsp.config("*").
		opts = {
			ensure_installed = {
				"ts_ls",
				"eslint",
				"jsonls",
				"yamlls",
				"dockerls",
				"emmet_ls",
				"prismals",
				"gopls",
			},
		},
	},
}, {
	-- lazy.nvim options
	install = { colorscheme = { "aero" } },
})

--------------------------------------------------------------------
-- Startup splash (lua/splash.lua) — set vim.g.splash_disabled to skip
--------------------------------------------------------------------
require("splash").setup()

--------------------------------------------------------------------
-- LSP keymaps + diagnostics (attach-time, native API)
--------------------------------------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local bufnr = args.buf
		local o = function(desc)
			return { buffer = bufnr, silent = true, desc = desc }
		end
		-- definition commonly returns multiple locations for types (e.g. TS
		-- declaration merging), which triggers Neovim's default loclist
		-- panel; jump straight to the first match instead.
		map("n", "gd", function()
			vim.lsp.buf.definition({
				on_list = function(list)
					vim.fn.setloclist(0, list.items)
					vim.cmd.lfirst()
				end,
			})
		end, o("goto definition"))
		map("n", "K", function()
			vim.lsp.buf.hover({ border = "solid" })
		end, o("hover"))
		map("n", "gy", vim.lsp.buf.type_definition, o("goto type definition"))
		map("n", "gi", vim.lsp.buf.implementation, o("goto implementation"))
		-- nowait: Neovim's global grr/grn/gra/gri/grt defaults share the "gr"
		-- prefix, so without it this waits out timeoutlen before firing.
		map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", o("references"), { nowait = true }))
		map("n", "<leader>rn", vim.lsp.buf.rename, o("rename"))
		map("n", "<leader>ac", vim.lsp.buf.code_action, o("code action"))
		map("n", "<leader>qf", function()
			vim.lsp.buf.code_action({ apply = true })
		end, o("quickfix"))

		local client = vim.lsp.get_client_by_id(args.data.client_id)

		-- ESLint's own fixAll (import sort, etc.) runs through its language
		-- server, not a CLI formatter — eslint_d would need a separate global
		-- install most projects don't have. Runs after conform's prettier pass
		-- (registered first, at startup); eslint-config-prettier disables the
		-- stylistic rules that would otherwise fight it.
		if client and client.name == "eslint" then
			vim.api.nvim_create_autocmd("BufWritePre", { buffer = bufnr, command = "LspEslintFixAll" })
		end

		-- Highlights other occurrences of the symbol under the cursor while
		-- idle; clears on cursor move.
		if client and client:supports_method("textDocument/documentHighlight") then
			local group = vim.api.nvim_create_augroup("lsp-document-highlight", { clear = false })
			vim.api.nvim_clear_autocmds({ buffer = bufnr, group = group })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				group = group,
				buffer = bufnr,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd("CursorMoved", {
				group = group,
				buffer = bufnr,
				callback = vim.lsp.buf.clear_references,
			})
		end
	end,
})

-- Diagnostic navigation (replaces coc [g / ]g)
map("n", "[g", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { silent = true })
map("n", "]g", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { silent = true })

-- <Esc> closes the hover/diagnostic float without moving the cursor. Targets
-- only that float (vim.lsp.util tracks it per buffer), so other floats like
-- the minimap stay open.
map("n", "<Esc>", function()
	local win = vim.b.lsp_floating_preview
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end, { desc = "Close hover float" })

vim.diagnostic.config({ virtual_text = true, float = { border = "solid" } })
