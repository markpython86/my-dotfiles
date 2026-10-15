# Neovim ai-help

Press `<leader>ai` in Neovim and ask “how do I …?” to get the exact keystrokes for this config. `:AiHelp` does the same from the command line, and visual mode sends the selection as extra context.

ai-help is intentionally small: it reads the current buffer state, loaded plugin names, and described keymaps, then asks a backend for a short answer optimized for this LazyVim setup.

## Usage

- `<leader>ai` in normal mode: ask a question.
- `<leader>ai` in visual mode: ask with the selected text attached.
- `:AiHelp [question]`: ask from the command line.
- `:{range}AiHelp`: attach those lines as the selection.

Popup keys:

| Key | Action |
|---|---|
| `q` / `<Esc>` | Close |
| `y` | Yank the first `code span` to `+` and `"` |
| `<CR>` | Ask a follow-up question |
| `r` | Retry the last question |

## Backends

Configure with `vim.g.ai_help` before use, for example in `lua/config/options.lua`.

```lua
vim.g.ai_help = {
  backend = "pi", -- "pi" or "openai"
  timeout = 30000,
  pi = { cmd = "pi", model = "vercel-ai-gateway/google/gemini-3.5-flash-lite" },
  openai = { endpoint = "https://api.deepseek.com", model = "deepseek-chat", api_key_env = "DEEPSEEK_API_KEY" },
}
```

The `openai` backend works with OpenAI-compatible providers such as DeepSeek, Groq, Ollama, OpenRouter, and Gemini's OpenAI-compatible endpoint. Ollama can use `api_key_env = false`.

## Privacy

Exactly what is sent: absolute buffer path, filetype, mode, a short built-in notes blurb about this config's remaps, loaded plugin names, the keymap list (buffer-local first, then global; only maps with a `desc`; capped around 12k characters), selected text if any, the question, and the last few ai-help turns. The `pi` backend also passes `--no-context-files`, so repo context files are not read.

## Minimal install: ai-help only

For an existing LazyVim config, copy:

| Source in this repo | Destination |
|---|---|
| `lua/plugins/ai-help.lua` | `~/.config/nvim/lua/plugins/ai-help.lua` |
| `lua/util/ai_help/` | `~/.config/nvim/lua/util/ai_help/` |

If your config does not already label `<leader>a`, keep the `which-key.nvim` spec in `lua/plugins/ai-help.lua`; it declares `{ "<leader>a", group = "+ai" }`.

## Full setup

The rest of `nvim/` is the supporting LazyVim-based setup exported with ai-help: `init.lua`, Lazy setup, options, keymaps, autocmds, utility helpers, and the UI/style plugin overrides. It was exported from a config running Neovim 0.12.2.

Third-party AI assistants and the lockfile were intentionally left out.

## Uninstall

For ai-help only, delete:

- `lua/plugins/ai-help.lua`
- `lua/util/ai_help/`

If you installed the full setup, remove the copied `nvim/` files from your Neovim config or restore your previous `~/.config/nvim` backup.
