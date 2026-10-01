-- Startup splash: a rotating, ordered-dithered skull above the recent files
-- under the launch directory. Shown only for a bare `nvim` (no args, no stdin).
local M = {}

-- Skull canvas in Braille cells; each cell is 2x4 dots, so 64x64 dots.
local SKULL_W, SKULL_H = 32, 16
local DOTS_W, DOTS_H = SKULL_W * 2, SKULL_H * 4
local FRAME_MS = 33
local RADIANS_PER_FRAME = 0.04
local MAX_FILES = 8
local FILES_TITLE = "Recent Files"
local NS = vim.api.nvim_create_namespace("splash")

-- Fraction of the way from the comment grey to the background.
local DIM_BLEND = 0.45
-- Fraction of the way from the comment grey to the normal foreground.
local SKULL_BLEND = 0.5
-- Frames to wait for lazy.nvim's startup time before showing stats without it.
local BOOT_WAIT_FRAMES = 60

local CAMERA_DISTANCE = 4
-- Tangent of the half field of view; the skull spans about 2.5 units at distance 4.
local FOCAL = 0.36
local VIEW_LIFT = 0.03
local BOUND_RADIUS = 1.6
local MARCH_STEPS = 48
local HIT_EPSILON = 0.003
local STEP_SCALE = 0.8
local AO_RADIUS = 0.2
local AMBIENT = 0.12
-- Above 1 spreads midtones so the dither gradient shows instead of a solid fill.
local TONE_GAMMA = 1.4
local RIM_STRENGTH = 0.5
local TOOTH_PITCH = 0.14

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

local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max

-- Lua locals are lexically scoped; declared up front so callers can sit above
-- the functions they call.
local define_highlights, blend, should_show, open, recent_files, file_labels
local build_info, git_parts, refresh_boot
local hide_chrome, restore_chrome
local map_keys, open_file, dismiss, close, start_animation, render, build_lines
local skull_lines, light_direction, render_dots, trace, shade, march
local skull_sdf, skull_normal, ellipsoid, smooth_min, smooth_max
local bayer_matrix, canvas_lines
local center, first_entry_line

local BAYER

function M.setup()
  BAYER = bayer_matrix()
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
  local fg, bg, text = color("Comment", "fg"), color("Normal", "bg"), color("Normal", "fg")
  if fg and bg then
    vim.api.nvim_set_hl(0, "SplashDim", { fg = blend(fg, bg, DIM_BLEND) })
  else
    vim.api.nvim_set_hl(0, "SplashDim", { link = "Comment" })
  end
  if fg and text then
    vim.api.nvim_set_hl(0, "SplashSkull", { fg = blend(fg, text, SKULL_BLEND) })
  else
    vim.api.nvim_set_hl(0, "SplashSkull", { link = "Comment" })
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
  local top_pad = center(SKULL_H + 1 + #state.info + file_rows, height)

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

  local indent = center(SKULL_W, width)
  local skull = skull_lines(state.angle)
  for _, text in ipairs(skull) do
    local line = string.rep(" ", indent) .. text
    lines[#lines + 1] = line
    marks[#marks + 1] = { row = #lines, col = indent, end_col = #line, hl = "SplashSkull" }
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

function skull_lines(angle)
  return canvas_lines(render_dots(angle))
end

function render_dots(angle)
  local yaw, pitch = angle, 0.12 * math.sin(angle * 0.6)
  local cy, sy, cp, sp = math.cos(-yaw), math.sin(-yaw), math.cos(-pitch), math.sin(-pitch)
  -- World -> object: undo the pitch about x, then the yaw about y.
  local function to_object(x, y, z)
    y, z = y * cp - z * sp, y * sp + z * cp
    return x * cy + z * sy, y, -x * sy + z * cy
  end

  local lx, ly, lz = light_direction(angle)
  lx, ly, lz = to_object(lx, ly, lz)
  local ox, oy, oz = to_object(0, 0, CAMERA_DISTANCE)

  local canvas = {}
  for row = 1, SKULL_H do
    canvas[row] = {}
    for col = 1, SKULL_W do canvas[row][col] = 0 end
  end

  for y = 0, DOTS_H - 1 do
    for x = 0, DOTS_W - 1 do
      local px = ((x + 0.5) / DOTS_W - 0.5) * 2 * FOCAL
      local py = (0.5 - (y + 0.5) / DOTS_H) * 2 * FOCAL - VIEW_LIFT
      local dx, dy, dz = to_object(px, py, -1)
      local len = sqrt(dx * dx + dy * dy + dz * dz)
      local brightness = trace(ox, oy, oz, dx / len, dy / len, dz / len, lx, ly, lz)
      if brightness and brightness > BAYER[(y % 8) * 8 + x % 8 + 1] then
        local row, col = math.floor(y / 4) + 1, math.floor(x / 2) + 1
        canvas[row][col] = bit.bor(canvas[row][col], DOT_BITS[y % 4 + 1][x % 2 + 1])
      end
    end
  end
  return canvas
end

-- Slow orbit that dips behind the skull so the face is rim-lit for a moment.
function light_direction(angle)
  local a = angle * 1.7
  local x, y, z = math.sin(a) * 1.0, 0.6, 0.25 + 0.5 * math.cos(a)
  local len = sqrt(x * x + y * y + z * z)
  return x / len, y / len, z / len
end

function trace(ox, oy, oz, dx, dy, dz, lx, ly, lz)
  local t = march(ox, oy, oz, dx, dy, dz)
  if not t then return nil end
  return shade(ox + dx * t, oy + dy * t, oz + dz * t, dx, dy, dz, lx, ly, lz)
end

-- Sphere-trace inside a bounding sphere so rays that miss cost almost nothing.
function march(ox, oy, oz, dx, dy, dz)
  local b = ox * dx + oy * dy + oz * dz
  local disc = b * b - (ox * ox + oy * oy + oz * oz - BOUND_RADIUS * BOUND_RADIUS)
  if disc < 0 then return nil end
  local root = sqrt(disc)
  local t, t_exit = -b - root, -b + root
  for _ = 1, MARCH_STEPS do
    local d = skull_sdf(ox + dx * t, oy + dy * t, oz + dz * t)
    if d < HIT_EPSILON then return t end
    t = t + d * STEP_SCALE
    if t > t_exit then return nil end
  end
  return nil
end

function shade(x, y, z, dx, dy, dz, lx, ly, lz)
  local nx, ny, nz = skull_normal(x, y, z)
  local lambert = max(0, nx * lx + ny * ly + nz * lz)
  -- Distance field sampled just off the surface darkens sockets and crevices.
  local occlusion = min(1, max(0, skull_sdf(x + nx * AO_RADIUS, y + ny * AO_RADIUS, z + nz * AO_RADIUS) / AO_RADIUS))
  local facing = max(0, -(nx * dx + ny * dy + nz * dz))
  local rim = (1 - facing) ^ 3 * RIM_STRENGTH
  local light = (AMBIENT + (1 - AMBIENT) * lambert) * (0.3 + 0.7 * occlusion) + rim
  return min(1, light) ^ TONE_GAMMA
end

function skull_normal(x, y, z)
  local e = 0.002
  local a = skull_sdf(x + e, y - e, z - e)
  local b = skull_sdf(x - e, y - e, z + e)
  local c = skull_sdf(x - e, y + e, z - e)
  local d = skull_sdf(x + e, y + e, z + e)
  local nx, ny, nz = a - b - c + d, -a - b + c + d, -a + b - c + d
  local len = sqrt(nx * nx + ny * ny + nz * nz)
  return nx / len, ny / len, nz / len
end

-- Object space: y up, face toward +z, roughly unit-radius cranium.
function skull_sdf(x, y, z)
  local ax = abs(x)
  local cranium = ellipsoid(x, y - 0.25, z + 0.1, 0.80, 0.85, 0.90)
  local midface = ellipsoid(x, y + 0.5, z - 0.3, 0.5, 0.5, 0.5)
  local d = smooth_min(cranium, midface, 0.25)

  local cheek = sqrt((ax - 0.5) ^ 2 + (y + 0.2) ^ 2 + (z - 0.5) ^ 2) - 0.22
  d = smooth_min(d, cheek, 0.15)

  local jaw = ellipsoid(x, y + 1.0, z - 0.1, 0.42, 0.26, 0.5)
  local ramus = ellipsoid(ax - 0.5, y + 0.7, z + 0.05, 0.1, 0.35, 0.2)
  d = smooth_min(d, smooth_min(jaw, ramus, 0.1), 0.08)

  local socket = sqrt((ax - 0.32) ^ 2 + (y - 0.05) ^ 2 + (z - 0.68) ^ 2) - 0.25
  d = smooth_max(d, -socket, 0.06)

  local nose = ellipsoid(x, y + 0.3, z - 0.85, 0.1, 0.17, 0.25)
  d = smooth_max(d, -nose, 0.04)

  local mouth = max(abs(y + 0.72) - 0.03, ax - 0.45, 0.2 - z)
  d = max(d, -mouth)

  local tooth_gap = abs((x + TOOTH_PITCH / 2) % TOOTH_PITCH - TOOTH_PITCH / 2)
  local groove = max(tooth_gap - 0.012, abs(y + 0.82) - 0.14, 0.35 - z)
  return max(d, -groove)
end

-- Exact only near the surface, which is all the marcher needs.
function ellipsoid(x, y, z, rx, ry, rz)
  local ax, ay, az = x / rx, y / ry, z / rz
  local k0 = sqrt(ax * ax + ay * ay + az * az)
  local bx, by, bz = ax / rx, ay / ry, az / rz
  local k1 = sqrt(bx * bx + by * by + bz * bz)
  if k1 == 0 then return -min(rx, ry, rz) end
  return k0 * (k0 - 1) / k1
end

function smooth_min(a, b, k)
  local h = max(k - abs(a - b), 0) / k
  return min(a, b) - h * h * k * 0.25
end

function smooth_max(a, b, k)
  return -smooth_min(-a, -b, k)
end

-- Row-major 8x8 ordered-dither thresholds in (0, 1), 1-indexed.
function bayer_matrix()
  local m, size = { 0 }, 1
  while size < 8 do
    local grown = {}
    for y = 0, size * 2 - 1 do
      for x = 0, size * 2 - 1 do
        local base = 4 * m[(y % size) * size + x % size + 1]
        local quadrant = ({ [0] = 0, 2, 3, 1 })[math.floor(y / size) * 2 + math.floor(x / size)]
        grown[y * size * 2 + x + 1] = base + quadrant
      end
    end
    m, size = grown, size * 2
  end
  for i = 1, #m do m[i] = (m[i] + 0.5) / 64 end
  return m
end

function canvas_lines(canvas)
  local lines = {}
  for row = 1, SKULL_H do
    local parts = {}
    for col = 1, SKULL_W do parts[col] = BRAILLE[canvas[row][col]] end
    lines[row] = table.concat(parts)
  end
  return lines
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
