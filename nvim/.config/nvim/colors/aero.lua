-- Aero — dark theme ported from the Zed theme at
-- zed/.config/zed/themes/Aero.json. Keep both in sync manually; there is no
-- shared palette source of truth between the two editors.

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "aero"

local c = {
  bg = "#161616",
  bg_dark = "#101010",
  bg_elevated = "#1e1e1e",
  bg_active_line = "#1d1d1d",
  fg = "#e2e2e2",
  fg_muted = "#888888",
  fg_disabled = "#3a3a3a",
  border = "#222222",
  border_focused = "#333333",
  line_nr = "#444444",
  line_nr_active = "#888888",
  accent = "#3898e0",
  comment = "#666672",
  comment_doc = "#75758a",
  string = "#5cc191",
  constant = "#e0ab4f",
  keyword = "#b483e8",
  func = "#3898e0",
  variable_special = "#e0ab4f",
  parameter = "#c9a8ec",
  operator = "#a8a8b3",
  punctuation = "#8a8a95",
  tag = "#f07686",
  attribute = "#e0ab4f",
  error = "#e0556e",
  warning = "#c79334",
  info = "#3366ff",
  hint = "#6e6e78",
  created = "#3fa372",
  deleted = "#e0556e",
  modified = "#c79334",
  -- nvim_set_hl rejects alpha hex, so these are #3366ff pre-blended over
  -- bg (#161616) at the source theme's alpha: selection 0x33/255, search 0x2e/255.
  selection = "#1c2645",
  search = "#1b2440",
}

local hl = vim.api.nvim_set_hl

-- Editor
hl(0, "Normal", { fg = c.fg, bg = c.bg })
hl(0, "NormalFloat", { fg = c.fg, bg = c.bg_elevated })
hl(0, "FloatBorder", { fg = c.border_focused, bg = c.bg_elevated })
hl(0, "EndOfBuffer", { fg = c.bg })
hl(0, "Cursor", { fg = c.bg, bg = c.fg })
hl(0, "CursorLine", { bg = c.bg_active_line })
hl(0, "CursorLineNr", { fg = c.line_nr_active, bold = true })
hl(0, "LineNr", { fg = c.line_nr })
hl(0, "SignColumn", { bg = "NONE" })
hl(0, "ColorColumn", { bg = c.bg_dark })
hl(0, "Visual", { bg = c.selection })
hl(0, "Search", { bg = c.search })
hl(0, "IncSearch", { fg = c.bg, bg = c.accent })
hl(0, "MatchParen", { fg = c.accent, bold = true })
hl(0, "NonText", { fg = c.fg_disabled, bg = "NONE" })
hl(0, "Whitespace", { fg = "#2a2a2a" })
hl(0, "Pmenu", { fg = c.fg, bg = c.bg_elevated })
hl(0, "PmenuSel", { fg = c.fg, bg = "#282828" })
hl(0, "PmenuSbar", { bg = c.bg_dark })
hl(0, "PmenuThumb", { bg = "#383838" })
hl(0, "StatusLine", { fg = c.fg, bg = c.bg_dark })
hl(0, "StatusLineNC", { fg = c.fg_muted, bg = c.bg_dark })
hl(0, "TabLine", { fg = c.fg_muted, bg = c.bg_dark })
hl(0, "TabLineFill", { bg = c.bg_dark })
hl(0, "TabLineSel", { fg = c.fg, bg = c.bg })
hl(0, "WinSeparator", { fg = c.border })
hl(0, "Title", { fg = c.accent, bold = true })
hl(0, "Directory", { fg = c.accent })

-- Syntax (legacy groups; treesitter groups below take priority when active)
hl(0, "Comment", { fg = c.comment, italic = true })
hl(0, "Constant", { fg = c.constant })
hl(0, "String", { fg = c.string })
hl(0, "Character", { fg = c.string })
hl(0, "Number", { fg = c.constant })
hl(0, "Boolean", { fg = c.constant })
hl(0, "Float", { fg = c.constant })
hl(0, "Identifier", { fg = c.fg })
hl(0, "Function", { fg = c.func })
hl(0, "Statement", { fg = c.keyword })
hl(0, "Conditional", { fg = c.keyword })
hl(0, "Repeat", { fg = c.keyword })
hl(0, "Label", { fg = c.keyword })
hl(0, "Operator", { fg = c.operator })
hl(0, "Keyword", { fg = c.keyword })
hl(0, "Exception", { fg = c.keyword })
hl(0, "PreProc", { fg = c.keyword })
hl(0, "Include", { fg = c.keyword })
hl(0, "Define", { fg = c.keyword })
hl(0, "Macro", { fg = c.keyword })
hl(0, "PreCondit", { fg = c.keyword })
hl(0, "Type", { fg = c.func })
hl(0, "StorageClass", { fg = c.keyword })
hl(0, "Structure", { fg = c.keyword })
hl(0, "Typedef", { fg = c.func })
hl(0, "Special", { fg = c.string })
hl(0, "SpecialChar", { fg = c.string })
hl(0, "Tag", { fg = c.tag })
hl(0, "Delimiter", { fg = c.punctuation })
hl(0, "SpecialComment", { fg = c.comment_doc })
hl(0, "Underlined", { underline = true })
hl(0, "Error", { fg = c.error })
hl(0, "Todo", { fg = c.bg, bg = c.constant, bold = true })

-- Treesitter
hl(0, "@comment", { link = "Comment" })
hl(0, "@comment.documentation", { fg = c.comment_doc })
hl(0, "@string", { link = "String" })
hl(0, "@string.escape", { fg = c.string })
hl(0, "@string.regexp", { fg = c.string })
hl(0, "@string.special", { fg = c.string })

-- Markdown inline/block code. Neovim's built-in default links @markup.raw
-- to Special. Use a plain chip instead: fg on element.background (c.border),
-- so code spans read as UI chrome rather than syntax-colored text.
hl(0, "@markup.raw", { fg = c.fg, bg = c.border })
hl(0, "@markup.raw.block", { fg = c.fg, bg = c.border })
hl(0, "@constant", { link = "Constant" })
hl(0, "@constant.builtin", { fg = c.constant })
hl(0, "@number", { fg = c.constant })
hl(0, "@boolean", { fg = c.constant })
hl(0, "@keyword", { link = "Keyword" })
hl(0, "@keyword.function", { fg = c.keyword })
hl(0, "@keyword.return", { fg = c.keyword })
hl(0, "@function", { link = "Function" })
hl(0, "@function.method", { fg = c.func })
hl(0, "@function.builtin", { fg = c.func })
hl(0, "@constructor", { fg = c.func })
hl(0, "@type", { link = "Type" })
hl(0, "@type.builtin", { fg = c.func })
hl(0, "@property", { fg = c.fg })
hl(0, "@variable", { fg = c.fg })
hl(0, "@variable.builtin", { fg = c.variable_special })
hl(0, "@variable.parameter", { fg = c.parameter })
hl(0, "@variable.member", { fg = c.fg })
hl(0, "@operator", { link = "Operator" })
hl(0, "@punctuation.bracket", { fg = c.punctuation })
hl(0, "@punctuation.delimiter", { fg = c.punctuation })
hl(0, "@punctuation.special", { fg = c.punctuation })
hl(0, "@tag", { link = "Tag" })
hl(0, "@tag.attribute", { fg = c.attribute })
hl(0, "@attribute", { fg = c.attribute })
hl(0, "@markup.link.url", { fg = c.func, underline = true })
hl(0, "@markup.link.label", { fg = c.func })
hl(0, "@markup.heading", { fg = c.func, bold = true })
hl(0, "@markup.strong", { bold = true })
hl(0, "@markup.italic", { italic = true })

-- LSP semantic tokens. Zed colors globals like JSON/Math/console via the
-- `defaultLibrary` token modifier, not a syntax rule — Treesitter has no
-- equivalent (its own builtin list omits these). The `readonly` modifier
-- was tried too, for imported consts, but the TS server sets it on every
-- `const` binding regardless of origin, so it over-applied.
hl(0, "@lsp.typemod.variable.defaultLibrary", { fg = c.variable_special })
hl(0, "@lsp.typemod.property.defaultLibrary", { fg = c.variable_special })
hl(0, "@lsp.typemod.function.defaultLibrary", { fg = c.variable_special })

-- @lsp.type.variable links to @variable (plain fg) by default. Semantic
-- tokens render above Treesitter, so once the LSP attaches it repaints
-- every variable — including all-caps consts Treesitter colors as @constant
-- — back to plain fg, undoing that highlight a second or two after the
-- file opens. Clear it so it contributes no color and Treesitter's own
-- capture (@constant or @variable) shows through underneath.
hl(0, "@lsp.type.variable", {})

-- Diagnostics
hl(0, "DiagnosticError", { fg = c.error })
hl(0, "DiagnosticWarn", { fg = c.warning })
hl(0, "DiagnosticInfo", { fg = c.info })
hl(0, "DiagnosticHint", { fg = c.hint })
hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = c.warning })
hl(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = c.info })
hl(0, "DiagnosticUnderlineHint", { undercurl = true, sp = c.hint })

-- Diff — same treatment as the material.nvim override in init.lua: saturated
-- backgrounds and no `reverse`, so diffview/fugitive/unified.nvim stay readable
-- on a low-saturation dark background.
hl(0, "DiffAdd", { bg = "#14432a" })
hl(0, "DiffDelete", { bg = "#4d2226" })
hl(0, "DiffChange", { bg = "#2e3c52" })
hl(0, "DiffText", { bg = "#36537a" })

-- GitSigns
hl(0, "GitSignsAdd", { fg = c.created })
hl(0, "GitSignsChange", { fg = c.modified })
hl(0, "GitSignsDelete", { fg = c.deleted })
-- Default links to NonText (fg_disabled, near-bg — meant for tildes/eol
-- markers, too dark to read here). Use the same muted gray as StatusLineNC.
hl(0, "GitSignsCurrentLineBlame", { fg = c.fg_muted })

-- Terminal ANSI colors (ported verbatim from Aero.json's terminal.ansi.*,
-- including its bright_black == white quirk)
vim.g.terminal_color_0 = "#1f1f1f"
vim.g.terminal_color_1 = "#f81118"
vim.g.terminal_color_2 = "#2dc55e"
vim.g.terminal_color_3 = "#ecba0f"
vim.g.terminal_color_4 = "#2a84d2"
vim.g.terminal_color_5 = "#4e5ab7"
vim.g.terminal_color_6 = "#1081d6"
vim.g.terminal_color_7 = "#d6dbe5"
vim.g.terminal_color_8 = "#d6dbe5"
vim.g.terminal_color_9 = "#de352e"
vim.g.terminal_color_10 = "#1dd361"
vim.g.terminal_color_11 = "#f3bd09"
vim.g.terminal_color_12 = "#1081d6"
vim.g.terminal_color_13 = "#5350b9"
vim.g.terminal_color_14 = "#0f7ddb"
vim.g.terminal_color_15 = "#ffffff"
