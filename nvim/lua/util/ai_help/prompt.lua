local M = {}

M.system = [[You are an expert on Neovim, LazyVim and the user's exact Neovim configuration.
The user asks "how do I ... in neovim?". Answer with the precise keystrokes or commands for THEIR config.

Rules:
- Give the exact keystrokes/commands FIRST, in backticks (e.g. `<leader>ff`). <leader> is <Space>.
- Then a 1-2 line explanation.
- Offer at most 2 alternatives.
- Mention if a key comes from a specific plugin.
- Prefer the user's custom mappings over defaults.
- NEVER invent keymaps that are not in the provided context, unless they are Vim builtins.
- Keep the whole answer under ~12 lines. Use markdown.
- The context lists effective keymaps as `mode<TAB>lhs<TAB>desc`; only mappings with a description are listed.]]

---@param question string
---@param ctx string context text from context.build()
---@param history {q:string,a:string}[]
---@param selection string|nil
---@return string
function M.user_message(question, ctx, history, selection)
  local parts = { "## Neovim environment\n" .. ctx }
  if selection and selection ~= "" then
    parts[#parts + 1] = "## Selection\nThe user has this text selected:\n```\n" .. selection .. "\n```"
  end
  if history and #history > 0 then
    local h = {}
    for _, t in ipairs(history) do
      h[#h + 1] = "Q: " .. t.q .. "\nA: " .. t.a
    end
    parts[#parts + 1] = "## Previous conversation\n" .. table.concat(h, "\n\n")
  end
  parts[#parts + 1] = "## Question\n" .. question
  return table.concat(parts, "\n\n")
end

return M
