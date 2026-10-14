# herdr which-key popup

Press `ctrl+b` in [herdr](https://herdr.dev) and a popup lists the actions you use most. Press the key next to
an action to run it, or `esc` to close.

```
   Panes                      Tabs                       Workspace                  via ctrl+alt+b
    v → Split right            c → New tab                N → New workspace          g → Go to agent
    - → Split down             n → Next tab               W → Rename workspace       w → Workspaces
 hjkl → Focus pane             p → Previous tab           D → Close workspace        ? → All keybindings
 HJKL → Swap pane            1-9 → Go to tab              R → Reload config          s → Settings
    z → Zoom                   T → Rename tab           C-b → Send ctrl+b            [ → Copy mode
    r → Resize mode            X → Close tab                                         e → Edit scrollback
    P → Rename pane                                                                  b → Toggle sidebar
    x → Close pane                                                                   o → Open notification
                                                                                     G → New worktree
                                                                                     q → Detach

                              esc close   ctrl+alt+b + key for native screens
```

(The real popup also shows a small icon next to each action if your terminal uses a Nerd Font.)

The keys match herdr's default prefix bindings, so `ctrl+b v` still splits right and `ctrl+b c` still opens a
tab. `ctrl+b ctrl+b` sends a literal `ctrl+b` to the pane.

## What it changes

The popup is bound to plain `ctrl+b`, which is also herdr's default prefix. So installing it **moves herdr's own
prefix to `ctrl+alt+b`**. Every default `prefix+...` binding keeps working under the new prefix. Use it for the
screens the popup can't open (go to agent, workspaces, settings, copy mode, detach, and so on). If you would
rather keep `ctrl+b` as your prefix, `INSTALL_PROMPT.md` explains how to bind the popup to a different key.

## Requirements

- herdr (developed on 0.9.3) and `python3` on your `PATH`. Python 3.11+ is recommended so the script can read your
  `config.toml`; older versions still work with defaults.
- Optional: a [Nerd Font](https://www.nerdfonts.com) in your terminal for the icons. Set `HERDR_WHICHKEY_ICONS=0`
  to turn them off.

## Install, with an AI coding agent (recommended)

1. Clone this repo and open it in your coding agent:

   ```sh
   git clone https://github.com/markpython86/my-dotfiles.git
   cd my-dotfiles
   ```

2. Tell the agent:

   > Follow INSTALL_PROMPT.md to set up the herdr which-key popup on this machine.

The agent checks your setup, backs up your config, installs the script, merges the config, validates it, and
asks you to press `ctrl+b` to confirm. It will ask before changing anything.

## Install by hand

From the root of this repo:

```sh
CFG=~/.config/herdr
mkdir -p "$CFG/scripts"
cp herdr/scripts/whichkey.py "$CFG/scripts/" && chmod +x "$CFG/scripts/whichkey.py"

[ -f "$CFG/config.toml" ] && cp "$CFG/config.toml" "$CFG/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
if grep -qs '^\[keys\]' "$CFG/config.toml"; then
  echo "You already have a [keys] table. Merge herdr/config.snippet.toml by hand (see INSTALL_PROMPT.md, step 3)."
else
  printf '\n' >> "$CFG/config.toml" && cat herdr/config.snippet.toml >> "$CFG/config.toml"
fi

herdr config check
```

`herdr config check` should print `config: ok`. Then apply it with `herdr server reload-config`, or just start herdr if
it isn't running yet. If you already have a `[keys]` table you must merge by hand: TOML allows only one, and a
duplicate makes herdr fall back to its defaults.

To preview the menu without touching herdr: `python3 ~/.config/herdr/scripts/whichkey.py --preview 120`.

## Undo

Restore the `config.toml.bak-...` file that was created during install, then run `herdr server reload-config`.

## What's in this repo

| Path | What it is |
|---|---|
| `herdr/scripts/whichkey.py` | The popup menu script. Each key runs a herdr CLI command. |
| `herdr/config.snippet.toml` | The `ctrl+b` popup binding and the prefix change, to merge into your `config.toml`. |
| `INSTALL_PROMPT.md` | Step-by-step instructions written for an AI agent, including customization and troubleshooting. |
