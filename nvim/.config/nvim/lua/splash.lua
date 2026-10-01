-- Startup splash: a rotating, ordered-dithered bust of David above the recent files
-- under the launch directory. Shown only for a bare `nvim` (no args, no stdin).
local M = {}

-- Bust canvas in Braille cells (2x4 dots each). Width is twice the height so the
-- dots stay square; height shrinks to fit short windows.
local MAX_BUST_H, MIN_BUST_H = 16, 10
-- Blank lines between the bust and the build info below it.
local BUST_GAP = 4
local MESH_PATH = vim.fn.stdpath("config") .. "/assets/bust.bin"
local FRAME_MS = 33
local RADIANS_PER_FRAME = 0.02
local MAX_FILES = 8
local FILES_TITLE = "Recent Files"
local NS = vim.api.nvim_create_namespace("splash")

-- Fraction of the way from the comment grey to the background.
local DIM_BLEND = 0.45
-- Fraction of the way from the comment grey to the normal foreground.
local BUST_BLEND = 0.5
-- Frames to wait for lazy.nvim's startup time before showing stats without it.
local BOOT_WAIT_FRAMES = 60

-- Far and narrow so the spinning head keeps a steady size instead of swelling
-- as it turns toward the camera.
local CAMERA_DISTANCE = 8
-- Tangent of the half field of view; the bust spans about 2.6 units at distance 8.
local FOCAL = 0.18
local AMBIENT = 0.1
-- Above 1 spreads midtones so the dither gradient shows instead of a solid fill.
local TONE_GAMMA = 1.7
local RIM_STRENGTH = 0.5

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

local ffi = require("ffi")
local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

-- Lua locals are lexically scoped; declared up front so callers can sit above
-- the functions they call.
local define_highlights, blend, should_show, open, recent_files, file_labels
local build_info, git_parts, refresh_boot
local hide_chrome, restore_chrome
local map_keys, open_file, dismiss, close, start_animation, render, build_lines
local bust_lines, load_mesh, light_direction, new_buffers, project_vertices
local fill_triangles, vertex_brightness, to_canvas
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
    vim.api.nvim_set_hl(0, "SplashBust", { fg = blend(fg, text, BUST_BLEND) })
  else
    vim.api.nvim_set_hl(0, "SplashBust", { link = "Comment" })
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
  if vim.fn.filereadable(MESH_PATH) == 0 then return false end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified then return false end
  return vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function open()
  local state = { win = vim.api.nvim_get_current_win(), angle = 0, frame = 0, entries = {} }
  state.mesh = load_mesh()
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
  local chrome = BUST_GAP + #state.info + file_rows
  local bust_h = min(MAX_BUST_H, max(MIN_BUST_H, height - chrome))
  local top_pad = center(bust_h + chrome, height)

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

  local indent = center(bust_h * 2, width)
  local bust = bust_lines(state, bust_h * 2, bust_h)
  for _, text in ipairs(bust) do
    local line = string.rep(" ", indent) .. text
    lines[#lines + 1] = line
    marks[#marks + 1] = { row = #lines, col = indent, end_col = #line, hl = "SplashBust" }
  end

  for _ = 1, BUST_GAP do lines[#lines + 1] = "" end
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

function bust_lines(state, cells_w, cells_h)
  local buf = new_buffers(state, cells_w * 2, cells_h * 4)
  project_vertices(state.mesh, buf, state.angle)
  fill_triangles(state.mesh, buf)
  return canvas_lines(to_canvas(buf), cells_w, cells_h)
end

-- Layout from scripts/bake-bust.py; `raw` is kept so the cdata views stay valid.
function load_mesh()
  local file = assert(io.open(MESH_PATH, "rb"))
  local raw = file:read("*a")
  file:close()
  local bytes = ffi.cast("const uint8_t*", raw)
  local header = ffi.cast("const uint32_t*", bytes)
  local count, triangles = header[0], header[1]
  local normals_at = 8 + count * 12
  local indices_at = normals_at + count * 3 + (count * 3) % 2
  return {
    raw = raw,
    count = count,
    triangles = triangles,
    positions = ffi.cast("const float*", bytes + 8),
    normals = ffi.cast("const int8_t*", bytes + normals_at),
    indices = ffi.cast("const uint16_t*", bytes + indices_at),
  }
end

function new_buffers(state, dots_w, dots_h)
  local buf = state.buffers
  if buf and buf.w == dots_w and buf.h == dots_h then return buf end
  local count = state.mesh.count
  buf = {
    w = dots_w,
    h = dots_h,
    sx = ffi.new("double[?]", count),
    sy = ffi.new("double[?]", count),
    sz = ffi.new("double[?]", count),
    shade = ffi.new("double[?]", count),
    depth = ffi.new("double[?]", dots_w * dots_h),
    tone = ffi.new("double[?]", dots_w * dots_h),
  }
  state.buffers = buf
  return buf
end

-- Spin about the vertical axis with the camera level, project to dot
-- coordinates, and light each vertex; triangles interpolate the result.
function project_vertices(mesh, buf, angle)
  local cy, sy = math.cos(angle), math.sin(angle)
  local lx, ly, lz = light_direction(angle)
  local pos, nrm = mesh.positions, mesh.normals
  local half_w, half_h = buf.w / 2, buf.h / 2
  local scale = 1 / FOCAL

  for i = 0, mesh.count - 1 do
    local x, y, z = pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]
    x, z = x * cy + z * sy, -x * sy + z * cy
    local w = CAMERA_DISTANCE - z
    buf.sx[i] = half_w + x / w * scale * half_w
    buf.sy[i] = half_h - y / w * scale * half_h
    buf.sz[i] = z

    local nx, ny, nz = nrm[i * 3] / 127, nrm[i * 3 + 1] / 127, nrm[i * 3 + 2] / 127
    nx, nz = nx * cy + nz * sy, -nx * sy + nz * cy
    buf.shade[i] = vertex_brightness(nx, ny, nz, lx, ly, lz)
  end
end

function vertex_brightness(nx, ny, nz, lx, ly, lz)
  local lambert = max(0, nx * lx + ny * ly + nz * lz)
  local rim = (1 - max(0, nz)) ^ 3 * RIM_STRENGTH
  return min(1, AMBIENT + (1 - AMBIENT) * lambert + rim) ^ TONE_GAMMA
end

-- Upper-left key light that drifts across the face; straight-on light would
-- flatten it, so it never reaches the camera axis.
function light_direction(angle)
  local x, y, z = -0.7 + 0.6 * math.sin(angle * 0.9), 0.35, 0.55
  local len = sqrt(x * x + y * y + z * z)
  return x / len, y / len, z / len
end

-- Z-buffered scanline fill sampling at dot centres. Front faces wind
-- counter-clockwise on screen, which is negative area with y pointing down.
function fill_triangles(mesh, buf)
  local sx, sy, sz, shade = buf.sx, buf.sy, buf.sz, buf.shade
  local depth, tone, w, h = buf.depth, buf.tone, buf.w, buf.h
  local idx = mesh.indices
  for i = 0, w * h - 1 do depth[i] = -1e9 end

  for t = 0, mesh.triangles - 1 do
    local a, b, c = idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]
    local x0, y0, x1, y1, x2, y2 = sx[a], sy[a], sx[b], sy[b], sx[c], sy[c]
    local area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
    if area < 0 then
      local inv = 1 / area
      local min_x, max_x = max(0, floor(min(x0, x1, x2))), min(w - 1, floor(max(x0, x1, x2)))
      local min_y, max_y = max(0, floor(min(y0, y1, y2))), min(h - 1, floor(max(y0, y1, y2)))
      for y = min_y, max_y do
        local py = y + 0.5
        for x = min_x, max_x do
          local px = x + 0.5
          local w0 = ((x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)) * inv
          local w1 = ((x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)) * inv
          local w2 = 1 - w0 - w1
          if w0 >= 0 and w1 >= 0 and w2 >= 0 then
            local z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c]
            local cell = y * w + x
            if z > depth[cell] then
              depth[cell] = z
              tone[cell] = w0 * shade[a] + w1 * shade[b] + w2 * shade[c]
            end
          end
        end
      end
    end
  end
end

-- Ordered dither: a dot is on when its tone beats the Bayer threshold.
function to_canvas(buf)
  local canvas = {}
  for row = 1, buf.h / 4 do
    canvas[row] = {}
    for col = 1, buf.w / 2 do canvas[row][col] = 0 end
  end
  for y = 0, buf.h - 1 do
    for x = 0, buf.w - 1 do
      local cell = y * buf.w + x
      if buf.depth[cell] > -1e8 and buf.tone[cell] > BAYER[(y % 8) * 8 + x % 8 + 1] then
        local row, col = floor(y / 4) + 1, floor(x / 2) + 1
        canvas[row][col] = bit.bor(canvas[row][col], DOT_BITS[y % 4 + 1][x % 2 + 1])
      end
    end
  end
  return canvas
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

function canvas_lines(canvas, cells_w, cells_h)
  local lines = {}
  for row = 1, cells_h do
    local parts = {}
    for col = 1, cells_w do parts[col] = BRAILLE[canvas[row][col]] end
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
