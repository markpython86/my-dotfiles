# Neovim ai-help

Press `<leader>ai` in Neovim and ask “how do I …?” to get the exact keystrokes for this LazyVim config. ai-help is small: it reads the current buffer state, loaded plugin names, and described keymaps, then asks an OpenAI-compatible backend for a short answer.

```text
You: How do I delete a word backwards?

ai-help: Press `db` in normal mode.
That is a custom mapping in `nvim/lua/config/keymaps.lua` (`Delete a word backwards`).
```

## Quickstart (ai-help only, into an existing LazyVim)

1. Copy the two ai-help paths into your LazyVim config:

   ```sh
   mkdir -p ~/.config/nvim/lua/plugins ~/.config/nvim/lua/util
   cp nvim/lua/plugins/ai-help.lua ~/.config/nvim/lua/plugins/ai-help.lua
   cp -r nvim/lua/util/ai_help ~/.config/nvim/lua/util/ai_help
   ```

2. Export a [Vercel AI Gateway](https://vercel.com/ai-gateway) key:

   ```sh
   export AI_GATEWAY_API_KEY=...
   ```

3. Restart `nvim`.

4. Press `<leader>ai`.

It works out of the box. You do not need to set `vim.g.ai_help` unless you want to change provider or model.

## Use any provider

All you need is an OpenAI-compatible endpoint, a model, and the environment variable that holds the API key. Set `vim.g.ai_help` before use, for example in `lua/config/options.lua`. Values deep-merge over the defaults, so you can override only the fields you need.

### Vercel AI Gateway (default)

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "https://ai-gateway.vercel.sh/v1",
    model = "google/gemini-2.5-flash-lite",
    api_key_env = "AI_GATEWAY_API_KEY",
  },
}
```

### OpenAI

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "https://api.openai.com/v1",
    model = "gpt-4.1-mini",
    api_key_env = "OPENAI_API_KEY",
  },
}
```

### DeepSeek

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "https://api.deepseek.com",
    model = "deepseek-chat",
    api_key_env = "DEEPSEEK_API_KEY",
  },
}
```

### Groq

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "https://api.groq.com/openai/v1",
    model = "llama-3.3-70b-versatile",
    api_key_env = "GROQ_API_KEY",
  },
}
```

### OpenRouter

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "https://openrouter.ai/api/v1",
    model = "openai/gpt-4.1-mini",
    api_key_env = "OPENROUTER_API_KEY",
  },
}
```

### Gemini OpenAI-compatible

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "https://generativelanguage.googleapis.com/v1beta/openai",
    model = "gemini-2.5-flash-lite",
    api_key_env = "GEMINI_API_KEY",
  },
}
```

### Ollama

```lua
vim.g.ai_help = {
  backend = "openai",
  openai = {
    endpoint = "http://localhost:11434/v1",
    model = "qwen2.5-coder",
    api_key_env = false,
  },
}
```

### pi CLI (author's alternative)

```lua
vim.g.ai_help = {
  backend = "pi",
  pi = {
    cmd = "pi",
    model = "vercel-ai-gateway/google/gemini-3.5-flash-lite",
  },
}
```

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

## Privacy

Exactly what is sent: absolute buffer path, filetype, mode, a short built-in notes blurb about this config's remaps, loaded plugin names, the keymap list (buffer-local first, then global; only maps with a `desc`; capped around 12k characters), selected text if any, the question, and the last few ai-help turns. The `pi` backend also passes `--no-context-files`, so repo context files are not read.

## Full setup (the whole `nvim/` config)

### Requirements

- Neovim 0.10+. ai-help uses `vim.system`, and LazyVim also needs 0.10+. This export is developed on 0.12.
- `git`.
- A Nerd Font in your terminal.
- Optional tools for some LazyVim extras: `node`/`npm` for prettier, typescript, eslint, and oxlint; `cargo` for rust. Missing tools usually just show Mason warnings until you install them.

### Install

Back up your current Neovim config and data, then copy this repo's `nvim/` directory into place:

```sh
TS=$(date +%Y%m%d-%H%M%S)
[ -e ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak-$TS
[ -e ~/.local/share/nvim ] && mv ~/.local/share/nvim ~/.local/share/nvim.bak-$TS
cp -r nvim ~/.config/nvim
nvim
```

On first start, `lazy.nvim` bootstraps itself and installs about 60 plugins. Then run:

```vim
:checkhealth lazy
```

There is no `lazy-lock.json`, so plugins are unpinned. If something breaks after install or later updates, run:

```vim
:Lazy sync
```

Third-party AI assistants were left out. ai-help is the only AI feature in this export.

## Uninstall / Undo

For ai-help only, delete the two copied paths:

```sh
rm -rf ~/.config/nvim/lua/plugins/ai-help.lua
rm -rf ~/.config/nvim/lua/util/ai_help
```

For the full setup, restore the `.bak-` directories you made during install:

```sh
rm -rf ~/.config/nvim ~/.local/share/nvim
mv ~/.config/nvim.bak-YYYYMMDD-HHMMSS ~/.config/nvim
mv ~/.local/share/nvim.bak-YYYYMMDD-HHMMSS ~/.local/share/nvim
```
