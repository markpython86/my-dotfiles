local M = {}

local MAX_CHARS = 12000

local NOTES = [[Notes about this config:
- Leader is <Space>. This is LazyVim with custom remaps.
- `d` and `D` delete WITHOUT yanking; `x` cuts, `xx` cuts a line, and `X` cuts to end of line.
- `db` deletes a word backwards. Visual `p` pastes without overwriting the register. `Q` records macros (`q` is disabled).
- `<C-h>`/`<C-l>` jump to line start/end (not window nav); `<C-z>` undo; `<S-M-j>/<S-M-k>` duplicate line down/up.]]

local MODES = { "n", "v", "x", "i", "t", "o" }

local function clean(s)
  return (s:gsub("[\t\n\r]", " "))
end

-- nvim_get_keymap returns the *expanded* leader (a literal space for <Space>),
-- which makes the model think `<leader>h` is just `h`. Render it back as <leader>.
local function pretty_lhs(lhs)
  local leader = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  if leader == " " then
    lhs = lhs:gsub("^ ", "<leader>")
  elseif leader ~= "" then
    lhs = lhs:gsub("^" .. vim.pesc(leader), "<leader>")
  end
  if localleader ~= "" and localleader ~= leader then
    lhs = lhs:gsub("^" .. vim.pesc(localleader), "<localleader>")
  end
  -- any remaining literal spaces (e.g. "<leader> " or mid-sequence) become <Space>
  return (lhs:gsub(" ", "<Space>"))
end

local function collect(getter, seen, out)
  for _, mode in ipairs(MODES) do
    for _, m in ipairs(getter(mode)) do
      local key = mode .. "\0" .. m.lhs
      if not seen[key] then
        seen[key] = true -- undescribed maps still shadow lower-priority ones
        if m.desc and m.desc ~= "" then
          out[#out + 1] = string.format("%s\t%s\t%s", mode, pretty_lhs(clean(m.lhs)), clean(m.desc))
        end
      end
    end
  end
end

---@param opts? {mode?:string}
---@return string
function M.build(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()
  local head = {
    "mode: " .. (opts.mode or vim.fn.mode()),
    "filetype: " .. (vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "(none)"),
    "buffer: " .. (vim.api.nvim_buf_get_name(buf) ~= "" and vim.api.nvim_buf_get_name(buf) or "(unnamed)"),
    "",
    NOTES,
  }

  local plugins = {}
  local ok, lazy = pcall(require, "lazy")
  if ok then
    for _, p in ipairs(lazy.plugins()) do
      if p._.loaded then
        plugins[#plugins + 1] = p.name
      end
    end
    table.sort(plugins)
  end
  local plug_txt = "\nLoaded plugins: " .. table.concat(plugins, ", ")

  -- buffer-local maps first (most specific), then global (<1ms, uncached); one shared `seen` set
  local maps, seen = {}, {}
  collect(function(mode)
    return vim.api.nvim_buf_get_keymap(buf, mode)
  end, seen, maps)
  collect(vim.api.nvim_get_keymap, seen, maps)

  local base = table.concat(head, "\n") .. plug_txt
  if #base > MAX_CHARS - 500 then
    base = base:sub(1, MAX_CHARS - 500)
  end
  local budget = MAX_CHARS - #base - 60
  local kept, used = {}, 0
  for _, l in ipairs(maps) do
    used = used + #l + 1
    if used > budget then
      kept[#kept + 1] = "... (keymap list truncated)"
      break
    end
    kept[#kept + 1] = l
  end
  return base .. "\n\nKeymaps (mode<TAB>lhs<TAB>desc):\n" .. table.concat(kept, "\n")
end

return M
