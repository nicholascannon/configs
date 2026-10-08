-- Lualine looks for a theme named after vim.g.colors_name before falling back
-- to "auto", so this is picked up for the aero colorscheme. Hex values are
-- copied from colors/aero.lua (its palette is local to that file).
local c = {
  bg = "#161616",
  bg_dark = "#101010",
  bg_elevated = "#1e1e1e",
  fg = "#e2e2e2",
  fg_muted = "#888888",
  white = "#e2e2e2",
  green = "#5cc191",
  blue = "#3898e0",
  purple = "#b483e8",
  amber = "#e0ab4f",
}

local function mode(color)
  return {
    a = { bg = color, fg = c.bg, gui = "bold" },
    b = { bg = c.bg_elevated, fg = color },
    c = { bg = c.bg_dark, fg = c.fg },
  }
end

local command = mode(c.blue)

return {
  normal = mode(c.white),
  insert = mode(c.green),
  visual = mode(c.purple),
  replace = mode(c.amber),
  command = command,
  terminal = command,
  inactive = {
    a = { bg = c.bg_dark, fg = c.fg_muted },
    b = { bg = c.bg_dark, fg = c.fg_muted },
    c = { bg = c.bg_dark, fg = c.fg_muted },
  },
}
