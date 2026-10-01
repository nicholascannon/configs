-- Startup splash: a rotating wireframe cube above the recent files under the
-- launch directory. Shown only for a bare `nvim` (no args, no stdin).
local M = {}

local CUBE_W, CUBE_H = 32, 16
local CUBE_SCALE = 12
local CAMERA_DISTANCE = 6
local FRAME_MS = 33
local RADIANS_PER_FRAME = 0.05
local MAX_FILES = 8
local FILES_TITLE = "Recent Files"
local NS = vim.api.nvim_create_namespace("splash")

-- Fraction of the way from the comment grey to the background.
local DIM_BLEND = 0.45
-- Frames to wait for lazy.nvim's startup time before showing stats without it.
local BOOT_WAIT_FRAMES = 60

local HIDDEN_WIN_OPTS = {
  wrap = false,
  number = false,
  relativenumber = false,
  signcolumn = "no",
  cursorline = false,
}

-- Braille cell bit for each dot, indexed [dot_row][dot_col] (2 wide x 4 tall).
local DOT_BITS = { { 0x01, 0x08 }, { 0x02, 0x10 }, { 0x04, 0x20 }, { 0x40, 0x80 } }
local BRAILLE = { [0] = " " }
for bits = 1, 255 do BRAILLE[bits] = vim.fn.nr2char(0x2800 + bits) end

local VERTICES = {
  { -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 },
  { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 },
}
-- Vertex indices per face (into VERTICES) and the face's outward normal.
local FACES = {
  { vertices = { 1, 2, 3, 4 }, normal = { 0, 0, -1 } },
  { vertices = { 5, 6, 7, 8 }, normal = { 0, 0, 1 } },
  { vertices = { 1, 2, 6, 5 }, normal = { 0, -1, 0 } },
  { vertices = { 4, 3, 7, 8 }, normal = { 0, 1, 0 } },
  { vertices = { 1, 4, 8, 5 }, normal = { -1, 0, 0 } },
  { vertices = { 2, 3, 7, 6 }, normal = { 1, 0, 0 } },
}

-- Lua locals are lexically scoped; declared up front so callers can sit above
-- the functions they call.
local define_highlights, blend, should_show, open, recent_files, file_labels
local build_info, git_parts, refresh_boot
local hide_chrome, restore_chrome
local map_keys, open_file, dismiss, close, start_animation, render, build_lines
local cube_lines, rotate, project, is_facing_camera, draw_face
local draw_edge, new_canvas, plot, canvas_lines
local center, first_entry_line

function M.setup()
  define_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = define_highlights })
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      if should_show() then open() end
    end,
  })
end

function define_highlights()
  local function color(group, key)
    return vim.api.nvim_get_hl(0, { name = group, link = false })[key]
  end
  local fg, bg = color("Comment", "fg"), color("Normal", "bg")
  if fg and bg then
    vim.api.nvim_set_hl(0, "SplashDim", { fg = blend(fg, bg, DIM_BLEND) })
  else
    vim.api.nvim_set_hl(0, "SplashDim", { link = "Comment" })
  end
end

function blend(from, to, amount)
  local rgb = 0
  for shift = 16, 0, -8 do
    local a = bit.band(bit.rshift(from, shift), 0xff)
    local b = bit.band(bit.rshift(to, shift), 0xff)
    rgb = bit.bor(rgb, bit.lshift(math.floor(a + (b - a) * amount + 0.5), shift))
  end
  return rgb
end

function should_show()
  if vim.fn.argc() > 0 or vim.g.splash_disabled then return false end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified then return false end
  return vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function open()
  local state = { win = vim.api.nvim_get_current_win(), angle = 0, frame = 0, entries = {} }
  state.files = recent_files()
  state.labels = file_labels(state.files)
  state.info = build_info()
  state.git = git_parts()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "splash"
  -- mini.map would otherwise open its float over the splash.
  vim.b[state.buf].minimap_disable = true
  vim.api.nvim_win_set_buf(state.win, state.buf)
  state.saved_win_opts = hide_chrome(state.win)

  render(state)
  local first = first_entry_line(state.entries)
  if first then vim.api.nvim_win_set_cursor(state.win, { first, 0 }) end

  map_keys(state)
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = state.buf,
    once = true,
    callback = function() close(state) end,
  })
  start_animation(state)
end

function recent_files()
  local root = vim.uv.cwd() .. "/"
  local files = {}
  for _, path in ipairs(vim.v.oldfiles) do
    if vim.startswith(path, root)
      and not path:find("/.git/", 1, true)
      and vim.fn.filereadable(path) == 1
    then
      files[#files + 1] = path
      if #files == MAX_FILES then break end
    end
  end
  return files
end

function file_labels(files)
  local labels = {}
  for i, path in ipairs(files) do
    labels[i] = string.format("%d  %s", i, vim.fn.fnamemodify(path, ":."))
  end
  return labels
end

function build_info()
  local version = vim.version()
  local build_type = vim.api.nvim_exec2("version", { output = true }).output:match("Build type: (%S+)")
  local uname = vim.uv.os_uname()
  local detail = table.concat({
    build_type or "unknown", jit.version, uname.sysname .. " " .. uname.machine,
  }, " · ")
  return {
    { text = string.format("NVIM v%d.%d.%d", version.major, version.minor, version.patch), hl = "Title" },
    { text = detail, hl = "SplashDim" },
    -- Filled in by refresh_boot once lazy.nvim has its startup time.
    { text = "", hl = "SplashDim" },
  }
end

function git_parts()
  local function git(...)
    local cmd = { "git", ... }
    local ok, result = pcall(function() return vim.system(cmd, { text = true }):wait() end)
    return ok and result.code == 0 and vim.trim(result.stdout) or nil
  end
  local branch = git("branch", "--show-current")
  if not branch then return {} end
  local changed = vim.split(git("status", "--porcelain") or "", "\n", { trimempty = true })
  return {
    branch ~= "" and branch or "detached",
    #changed == 0 and "clean" or (#changed .. " changed"),
  }
end

function refresh_boot(state)
  local ok, lazy = pcall(require, "lazy")
  local stats = ok and lazy.stats() or nil
  local timed = stats and stats.startuptime > 0
  if not timed and state.frame < BOOT_WAIT_FRAMES then return end

  local parts = {}
  if stats then parts[#parts + 1] = string.format("%d/%d plugins", stats.loaded, stats.count) end
  if timed then parts[#parts + 1] = string.format("%.0f ms", stats.startuptime) end
  vim.list_extend(parts, state.git)

  state.info[#state.info].text = table.concat(parts, " · ")
  state.boot_ready = true
end

function hide_chrome(win)
  local saved = {}
  for opt, value in pairs(HIDDEN_WIN_OPTS) do
    saved[opt] = vim.wo[win][opt]
    vim.wo[win][opt] = value
  end
  return saved
end

function restore_chrome(win, saved)
  if not vim.api.nvim_win_is_valid(win) then return end
  for opt, value in pairs(saved) do
    vim.wo[win][opt] = value
  end
end

function map_keys(state)
  local function bind(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, silent = true })
  end
  for i, path in ipairs(state.files) do
    bind(tostring(i), function() open_file(state, path) end)
  end
  bind("<CR>", function()
    local path = state.entries[vim.api.nvim_win_get_cursor(state.win)[1]]
    if path then open_file(state, path) end
  end)
  bind("q", function() dismiss(state) end)
  bind("<Esc>", function() dismiss(state) end)
end

function open_file(state, path)
  close(state)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

function dismiss(state)
  close(state)
  vim.cmd.enew()
end

-- Idempotent: runs from key actions and from BufWipeout (e.g. a file opened
-- from telescope while the splash is showing).
function close(state)
  if state.closed then return end
  state.closed = true
  if state.timer then
    state.timer:stop()
    state.timer:close()
  end
  restore_chrome(state.win, state.saved_win_opts)
end

function start_animation(state)
  state.timer = vim.uv.new_timer()
  state.timer:start(FRAME_MS, FRAME_MS, vim.schedule_wrap(function()
    if state.closed then return end
    state.angle = state.angle + RADIANS_PER_FRAME
    state.frame = state.frame + 1
    pcall(render, state)
  end))
end

function render(state)
  local win = vim.fn.bufwinid(state.buf)
  if win == -1 then return end

  if not state.boot_ready then refresh_boot(state) end
  local lines, marks, entries = build_lines(state, win)
  state.entries = entries

  local cursor = vim.api.nvim_win_get_cursor(win)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  pcall(vim.api.nvim_win_set_cursor, win, cursor)

  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(state.buf, NS, mark.row - 1, mark.col, {
      end_col = mark.end_col,
      hl_group = mark.hl,
    })
  end
end

function build_lines(state, win)
  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)
  local file_rows = #state.files > 0 and #state.files + 2 or 0
  local top_pad = center(CUBE_H + 1 + #state.info + file_rows, height)

  local lines, marks, entries = {}, {}, {}
  local function add_text(text, pad, hl)
    local line = string.rep(" ", pad) .. text
    lines[#lines + 1] = line
    if hl and text ~= "" then
      marks[#marks + 1] = { row = #lines, col = pad, end_col = #line, hl = hl }
    end
    return #lines
  end

  for _ = 1, top_pad do lines[#lines + 1] = "" end

  local indent = center(CUBE_W, width)
  local cube, cube_marks = cube_lines(state.angle)
  for _, text in ipairs(cube) do lines[#lines + 1] = string.rep(" ", indent) .. text end
  for _, mark in ipairs(cube_marks) do
    marks[#marks + 1] = {
      row = top_pad + mark.row,
      col = indent + mark.col,
      end_col = indent + mark.end_col,
      hl = mark.hl,
    }
  end

  lines[#lines + 1] = ""
  for _, item in ipairs(state.info) do
    add_text(item.text, center(vim.fn.strdisplaywidth(item.text), width), item.hl)
  end

  if #state.files > 0 then
    lines[#lines + 1] = ""
    local widest = 0
    for _, label in ipairs(state.labels) do
      widest = math.max(widest, vim.fn.strdisplaywidth(label))
    end
    local pad = center(widest, width)
    add_text(FILES_TITLE, pad, "Comment")
    for i, label in ipairs(state.labels) do
      entries[add_text(label, pad)] = state.files[i]
    end
  end
  return lines, marks, entries
end

function cube_lines(angle)
  local canvas = new_canvas()
  local points = {}
  for i, vertex in ipairs(VERTICES) do points[i] = project(rotate(vertex, angle)) end
  for _, face in ipairs(FACES) do
    local normal = rotate(face.normal, angle)
    if is_facing_camera(normal) then draw_face(canvas, points, face) end
  end
  return canvas_lines(canvas)
end

function rotate(v, angle)
  local x, y, z = v[1], v[2], v[3]

  local cos_y, sin_y = math.cos(angle), math.sin(angle)
  x, z = x * cos_y - z * sin_y, x * sin_y + z * cos_y

  local tilt = angle * 0.7 + 0.5
  local cos_x, sin_x = math.cos(tilt), math.sin(tilt)
  y, z = y * cos_x - z * sin_x, y * sin_x + z * cos_x

  return { x, y, z }
end

function project(v)
  local perspective = CAMERA_DISTANCE / (CAMERA_DISTANCE + v[3])
  -- Braille dots (2x4 per cell) are roughly square, so x and y share a scale.
  return {
    x = CUBE_W + v[1] * perspective * CUBE_SCALE,
    y = CUBE_H * 2 + v[2] * perspective * CUBE_SCALE,
  }
end

-- On the unit cube a face's centre is its normal, so the view vector from the
-- camera (at z = -CAMERA_DISTANCE) reduces to this.
function is_facing_camera(normal)
  return normal[3] * CAMERA_DISTANCE + 1 < 0
end

-- Only camera-facing faces are drawn, so their edges are exactly the visible
-- ones and no hidden-line pass is needed.
function draw_face(canvas, points, face)
  local count = #face.vertices
  for k, index in ipairs(face.vertices) do
    local next_index = face.vertices[k % count + 1]
    draw_edge(canvas, points[index], points[next_index])
  end
end

function new_canvas()
  local canvas = {}
  for row = 1, CUBE_H do
    canvas[row] = {}
    for col = 1, CUBE_W do canvas[row][col] = 0 end
  end
  return canvas
end

function plot(canvas, x, y)
  x, y = math.floor(x), math.floor(y)
  local col, row = math.floor(x / 2) + 1, math.floor(y / 4) + 1
  if col < 1 or col > CUBE_W or row < 1 or row > CUBE_H then return end
  canvas[row][col] = bit.bor(canvas[row][col], DOT_BITS[y % 4 + 1][x % 2 + 1])
end

-- Braille cells are 3 bytes, hence the byte-offset bookkeeping for the marks.
function canvas_lines(canvas)
  local lines, marks = {}, {}
  for row = 1, CUBE_H do
    local parts, byte = {}, 0
    for col = 1, CUBE_W do
      local bits = canvas[row][col]
      local char = BRAILLE[bits]
      parts[col] = char
      if bits ~= 0 then
        marks[#marks + 1] = {
          row = row,
          col = byte,
          end_col = byte + #char,
          hl = "Comment",
        }
      end
      byte = byte + #char
    end
    lines[row] = table.concat(parts)
  end
  return lines, marks
end

function draw_edge(canvas, from, to)
  local dx, dy = to.x - from.x, to.y - from.y
  local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy))))
  for i = 0, steps do
    local t = i / steps
    plot(canvas, from.x + dx * t, from.y + dy * t)
  end
end

function center(inner, outer)
  return math.max(0, math.floor((outer - inner) / 2))
end

function first_entry_line(entries)
  local first
  for line in pairs(entries) do first = math.min(first or line, line) end
  return first
end

return M
