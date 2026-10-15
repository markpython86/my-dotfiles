local M = {}

-- Any OpenAI-compatible provider works: set endpoint, model, and api_key_env.
M.defaults = {
  backend = "openai",
  timeout = 30000,
  pi = {
    cmd = "pi",
    model = "vercel-ai-gateway/google/gemini-3.5-flash-lite",
  },
  openai = {
    endpoint = "https://ai-gateway.vercel.sh/v1",
    model = "google/gemini-2.5-flash-lite",
    api_key_env = "AI_GATEWAY_API_KEY",
  },
}

function M.config()
  return vim.tbl_deep_extend("force", M.defaults, vim.g.ai_help or {})
end

local function neutral_cwd()
  local dir = vim.fn.stdpath("cache")
  vim.fn.mkdir(dir, "p")
  return dir
end

--- Each backend: run(cfg, req, cb) -> handle {cancel=fn}
--- req = { system=string, user=string, history={ {q,a} } }
--- cb(err|nil, text|nil)
local B = {}

local function finish_once(cb)
  local done = false
  return function(err, text)
    if done then
      return
    end
    done = true
    vim.schedule(function()
      cb(err, text)
    end)
  end
end

local function spawn(cmd, opts, cfg, done, on_exit)
  local cancelled = false
  local ok, proc = pcall(
    vim.system,
    cmd,
    vim.tbl_extend("force", { text = true, timeout = cfg.timeout }, opts),
    function(r)
      if cancelled then
        return done("cancelled")
      end
      if r.code == 124 or r.signal == 15 then
        return done("timed out after " .. math.floor(cfg.timeout / 1000) .. "s")
      end
      on_exit(r)
    end
  )
  if not ok then
    done("failed to start: " .. tostring(proc))
    return { cancel = function() end }
  end
  return {
    cancel = function()
      cancelled = true
      pcall(proc.kill, proc, 15)
    end,
  }
end

function B.pi(cfg, req, cb)
  local done = finish_once(cb)
  local c = cfg.pi
  if vim.fn.executable(c.cmd) ~= 1 then
    done("`" .. c.cmd .. "` not found in PATH")
    return { cancel = function() end }
  end
  local cmd = {
    c.cmd,
    "-p",
    "--no-tools",
    "--no-session",
    "--no-extensions",
    "--no-skills",
    "--no-context-files",
    "--no-mcp",
    "--no-prompt-templates",
    "--thinking",
    "off",
    "--model",
    c.model,
    "--system-prompt",
    req.system,
  }
  return spawn(cmd, { stdin = req.user, cwd = neutral_cwd() }, cfg, done, function(r)
    local out = vim.trim(r.stdout or "")
    if r.code ~= 0 or out == "" then
      local err = vim.trim(r.stderr or "")
      -- drop noisy model-pattern warnings
      err = table.concat(
        vim.tbl_filter(function(l)
          return not l:match("^Warning: No models match")
        end, vim.split(err, "\n")),
        "\n"
      )
      return done(("pi exited with code %d: %s"):format(r.code, vim.trim(err) ~= "" and err or "(no output)"))
    end
    done(nil, out)
  end)
end

function B.openai(cfg, req, cb)
  local done = finish_once(cb)
  local c = cfg.openai
  local key = c.api_key_env and vim.env[c.api_key_env] or nil
  if c.api_key_env and not key and not (c.endpoint or ""):match("localhost") then
    done(("environment variable %s is not set"):format(c.api_key_env))
    return { cancel = function() end }
  end
  local endpoint = c.endpoint:gsub("/+$", "")
  if not endpoint:match("/chat/completions$") then
    endpoint = endpoint .. "/chat/completions"
  end
  local messages = { { role = "system", content = req.system } }
  table.insert(messages, { role = "user", content = req.user })
  local body = vim.json.encode({ model = c.model, messages = messages, stream = false })
  local cmd = {
    "curl",
    "-sS",
    "--max-time",
    tostring(math.floor(cfg.timeout / 1000)),
    "-w",
    "\n%{http_code}",
    "-H",
    "Content-Type: application/json",
  }
  if key then
    vim.list_extend(cmd, { "-H", "Authorization: Bearer " .. key })
  end
  vim.list_extend(cmd, { "-d", "@-", endpoint })
  return spawn(cmd, { stdin = body, cwd = neutral_cwd() }, cfg, done, function(r)
    if r.code ~= 0 then
      return done(("curl failed (%d): %s"):format(r.code, vim.trim(r.stderr or "")))
    end
    local raw, status = (r.stdout or ""):match("^(.*)\n(%d+)%s*$")
    raw = raw or r.stdout or ""
    local ok, data = pcall(vim.json.decode, raw)
    if not ok or type(data) ~= "table" then
      return done(("HTTP %s: invalid JSON response: %s"):format(status or "?", raw:sub(1, 300)))
    end
    if data.error then
      local msg = type(data.error) == "table" and (data.error.message or vim.inspect(data.error))
        or tostring(data.error)
      return done(("HTTP %s: %s"):format(status or "?", msg))
    end
    local text = vim.tbl_get(data, "choices", 1, "message", "content")
    if type(text) ~= "string" or text == "" then
      return done(("HTTP %s: no content in response"):format(status or "?"))
    end
    done(nil, vim.trim(text))
  end)
end

---@return table handle
function M.run(req, cb)
  local cfg = M.config()
  local b = B[cfg.backend]
  if not b then
    vim.schedule(function()
      cb("unknown backend: " .. tostring(cfg.backend))
    end)
    return { cancel = function() end }
  end
  return b(cfg, req, cb)
end

return M
