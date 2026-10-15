local M = {}

local MAX_TURNS = 6
local history = {} ---@type {q:string,a:string}[]
local state = { handle = nil, win = nil, buf = nil, popup = nil, last = nil }

local function context()
  return require("util.ai_help.context")
end

local function first_code_span(text)
  return text:match("`([^`\n]+)`")
end

---Core, UI-less ask. opts: {selection=string, mode=string, context=string, history=table, on_done=fun(answer, err)}
---@return table handle
function M.ask(question, opts)
  opts = opts or {}
  local prompt = require("util.ai_help.prompt")
  local ctx = opts.context or context().build({ mode = opts.mode })
  local req = {
    system = prompt.system,
    user = prompt.user_message(question, ctx, opts.history or history, opts.selection),
  }
  return require("util.ai_help.backends").run(req, function(err, text)
    if err and err ~= "cancelled" then
      vim.notify("AiHelp: " .. err, vim.log.levels.ERROR)
    end
    if opts.on_done then
      opts.on_done(text, err)
    end
  end)
end

-- UI ---------------------------------------------------------------------

local function cancel_request()
  if state.handle then
    state.handle.cancel()
    state.handle = nil
  end
end

local function clear_state()
  state.win, state.buf, state.popup = nil, nil, nil
end

local function close()
  cancel_request()
  local popup, win = state.popup, state.win
  clear_state()
  if popup then
    pcall(function()
      popup:close()
    end)
  elseif win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

---Write lines to buf, normalizing embedded newlines.
local function set_lines(buf, lines)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    lines = vim.split(table.concat(lines, "\n"), "\n", { plain = true })
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end
end

local function open_win()
  close()
  local win_keys = {
    q = close,
    ["<Esc>"] = close,
    y = function()
      local text = table.concat(vim.api.nvim_buf_get_lines(state.buf, 0, -1, false), "\n")
      local code = first_code_span(text)
      if code then
        vim.fn.setreg("+", code)
        vim.fn.setreg('"', code)
        vim.notify("Yanked: " .. code)
      else
        vim.notify("AiHelp: no `code` span found", vim.log.levels.WARN)
      end
    end,
    ["<CR>"] = function()
      M.input({ followup = true })
    end,
    r = function()
      if state.last then
        M.run(state.last.q, state.last.opts)
      end
    end,
  }

  local ok, Snacks = pcall(function()
    return _G.Snacks and _G.Snacks.win
  end)
  if ok and Snacks then
    local keys = {}
    for k, fn in pairs(win_keys) do
      keys[k] = { k, fn, desc = "AiHelp" }
    end
    local w = Snacks({
      text = { "Thinking…" },
      width = 0.6,
      height = 0.5,
      border = "rounded",
      title = " AI Help ",
      title_pos = "center",
      wo = { wrap = true, linebreak = true, conceallevel = 2 },
      bo = { filetype = "markdown", modifiable = false },
      keys = keys,
      on_close = function()
        if state.popup == nil or state.popup == w then
          cancel_request()
          clear_state()
        end
      end,
    })
    state.win, state.buf, state.popup = w.win, w.buf, w
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  local W, H = math.floor(vim.o.columns * 0.6), math.floor(vim.o.lines * 0.5)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = W,
    height = H,
    row = math.floor((vim.o.lines - H) / 2),
    col = math.floor((vim.o.columns - W) / 2),
    style = "minimal",
    border = "rounded",
    title = " AI Help ",
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  state.win, state.buf = win, buf
  for k, fn in pairs(win_keys) do
    vim.keymap.set("n", k, fn, { buffer = buf, nowait = true, desc = "AiHelp" })
  end
  vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
    buffer = buf,
    once = true,
    callback = function()
      if state.buf == buf then
        cancel_request()
        clear_state()
      end
    end,
  })
end

---@param question string
---@param opts? {selection?:string, mode?:string, context?:string}
function M.run(question, opts)
  opts = opts or {}
  state.last = { q = question, opts = opts }
  open_win()
  local my_buf = state.buf
  set_lines(my_buf, { "**Q:** " .. question, "", "Thinking…" })
  state.handle = M.ask(question, {
    selection = opts.selection,
    mode = opts.mode,
    context = opts.context,
    on_done = function(answer, err)
      if state.buf ~= my_buf then
        return -- window closed or replaced
      end
      state.handle = nil
      if err then
        set_lines(my_buf, { "**Q:** " .. question, "", "**Error:** " .. err, "", "_r: retry · q: close_" })
        return
      end
      history[#history + 1] = { q = question, a = answer }
      while #history > MAX_TURNS do
        table.remove(history, 1)
      end
      local lines = vim.split(answer, "\n", { plain = true })
      vim.list_extend(lines, { "", "---", "_y: yank code · ⏎: follow-up · r: retry · q: close_" })
      set_lines(my_buf, lines)
    end,
  })
end

function M.input(opts)
  opts = opts or {}
  local prev = state.last
  local sel = opts.selection
  local mode, ctx = opts.mode, opts.context
  if opts.followup and prev then
    sel, mode, ctx = prev.opts.selection, prev.opts.mode, prev.opts.context
  end
  vim.ui.input({ prompt = opts.followup and "Follow-up: " or "How do I… (in neovim)? " }, function(q)
    if q and vim.trim(q) ~= "" then
      M.run(vim.trim(q), { selection = sel, mode = mode, context = ctx })
    end
  end)
end

--- Entry from keymap/command. `visual` -> capture last visual selection (x keymap);
--- `range` ({line1,line2}) -> use those buffer lines (command range).
function M.start(question, visual, range)
  local cur_mode = vim.fn.mode()
  local opts = { mode = visual and "v" or cur_mode }
  -- snapshot source-buffer context BEFORE any UI opens
  opts.context = context().build({ mode = opts.mode })
  if range then
    local lines = vim.api.nvim_buf_get_lines(0, range[1] - 1, range[2], false)
    if #lines > 0 then
      opts.selection = table.concat(lines, "\n"):sub(1, 3000)
    end
    opts.mode = "v"
  elseif visual then
    if cur_mode:match("^[vV\22]") then
      vim.cmd("normal! \27") -- leave visual so '< '> are set
    end
    local s, e = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    local ok, lines =
      pcall(vim.fn.getregion, s, e, { type = cur_mode:match("^[vV\22]") and cur_mode or vim.fn.visualmode() })
    if ok and #lines > 0 then
      opts.selection = table.concat(lines, "\n"):sub(1, 3000)
    end
  end
  if question and vim.trim(question) ~= "" then
    M.run(vim.trim(question), opts)
  else
    M.input(opts)
  end
end

function M.setup()
  if vim.fn.exists(":AiHelp") == 2 then
    return
  end
  vim.api.nvim_create_user_command("AiHelp", function(c)
    M.start(c.args, false, c.range > 0 and { c.line1, c.line2 } or nil)
  end, { nargs = "*", range = true, desc = "Ask how to do X in Neovim" })
end

return M
