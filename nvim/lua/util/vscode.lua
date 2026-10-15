local M = {}

--- Convert JSONC (comments + trailing commas, as VS Code allows) to strict JSON.
--- Walks the text so `//` inside strings (e.g. URLs) is left alone.
--- @param src string
--- @return string
local function jsonc_to_json(src)
  local out, n, i, len = {}, 0, 1, #src

  local function emit(s)
    n = n + 1
    out[n] = s
  end

  while i <= len do
    local c = src:sub(i, i)
    local two = src:sub(i, i + 1)

    if c == '"' then
      local j = i + 1
      while j <= len do
        local d = src:sub(j, j)
        if d == "\\" then
          j = j + 2
        elseif d == '"' then
          break
        else
          j = j + 1
        end
      end
      emit(src:sub(i, j))
      i = j + 1
    elseif two == "//" then
      i = (src:find("\n", i, true) or len + 1)
    elseif two == "/*" then
      local _, e = src:find("*/", i + 2, true)
      i = (e or len) + 1
    elseif c == "," and src:find("^%s*[}%]]", i + 1) then
      i = i + 1
    else
      emit(c)
      i = i + 1
    end
  end

  return table.concat(out)
end

---get full `.vscode/settings.json` as table
function M.get_settings()
  local filename = vim.fn.getcwd() .. "/.vscode/settings.json"

  if vim.fn.filereadable(filename) ~= 1 then
    return {}
  end

  local content = table.concat(vim.fn.readfile(filename), "\n")
  if content:match("^%s*$") then
    return {}
  end

  local ok, json = pcall(vim.json.decode, jsonc_to_json(content), { luanil = { object = true, array = true } })

  if not ok or type(json) ~= "table" then
    vim.notify_once("Could not parse " .. filename .. ", ignoring it", vim.log.levels.WARN)
    return {}
  end

  return json
end

---get `.vscode/settings.json` value by key
---@param key string table key
function M.get_setting(key)
  local settings = M.get_settings()
  return settings[key]
end

return M
