# ai-help

Ask "how do I … in neovim?" and get the exact keystrokes for **this** config.

See [`nvim/README.md`](../../../README.md) for the newcomer walkthrough, provider setup, full config install, and uninstall steps.

## Usage

- `<leader>ai` (normal/visual) or `:AiHelp [question]`.
- No argument: an input prompt opens. In visual mode the selection is sent as extra context.
- Popup keys: `q`/`<Esc>` close · `y` yank first `code span` to `"+` and `"` · `<CR>` follow-up (last 6 turns kept in memory) · `r` retry.
- `:{range}AiHelp` uses those buffer lines as the selection (max 3000 chars). Context is captured from the source buffer before the popup opens.
- Exactly what is sent: absolute buffer path, filetype, mode, a short built-in notes blurb about this config's remaps, loaded plugin names, the keymap list (buffer-local first, then global; only maps with a `desc`; capped ~12k chars), the selected text (if any), and prior conversation turns. The `pi` backend also passes `--no-context-files`, so AGENTS.md/CLAUDE.md are not read.

## Config (`vim.g.ai_help`, set before use, e.g. in `lua/config/options.lua`)

Defaults:

```lua
vim.g.ai_help = {
  backend = "openai", -- "openai" | "pi"
  timeout = 30000, -- ms
  openai = {
    endpoint = "https://ai-gateway.vercel.sh/v1",
    model = "google/gemini-2.5-flash-lite",
    api_key_env = "AI_GATEWAY_API_KEY",
  },
  pi = {
    cmd = "pi",
    model = "vercel-ai-gateway/google/gemini-3.5-flash-lite",
  },
}
```

Values are deep-merged with defaults. Any OpenAI-compatible provider works: set `endpoint`, `model`, and `api_key_env`. Use `api_key_env = false` for local providers that do not need a bearer token.

### Vercel AI Gateway (default)

```lua
vim.g.ai_help = { backend = "openai" } -- needs $AI_GATEWAY_API_KEY
```

### OpenAI-compatible provider

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

### pi CLI

```lua
vim.g.ai_help = { backend = "pi" }
```

The `pi` backend runs `pi -p` with no tools/session/extensions, prompt on stdin, from the nvim cache dir.

## Change the keymap

Edit the two `"<leader>ai"` entries in `lua/plugins/ai-help.lua`.

## Uninstall

Delete `lua/plugins/ai-help.lua` and `lua/util/ai_help/`. Nothing else is touched.
