# Install prompt: which-key popup for herdr

You are an AI coding agent. Help the user install the which-key popup for
[herdr](https://herdr.dev) from this directory. Read this whole file before changing anything.

## What this installs

Pressing `ctrl+b` inside herdr opens a popup menu that lists the essential actions. Press the key next
to an action to run it. The keys match herdr's default prefix bindings, so muscle memory still works:
`ctrl+b v` splits right, `ctrl+b c` opens a tab, and `ctrl+b ctrl+b` sends a literal `ctrl+b` to the pane.

| Group | Keys |
|---|---|
| Panes | `v` split right, `-` split down, `hjkl` focus, `HJKL` swap, `z` zoom, `r` resize mode, `P` rename, `x` close |
| Tabs | `c` new, `n` / `p` next / previous, `1-9` go to, `T` rename, `X` close |
| Workspace | `N` new, `W` rename, `D` close, `R` reload config, `C-b` send ctrl+b |
| `via ctrl+alt+b` (hints only) | `g` go to agent, `w` workspaces, `?` all keybindings, `s` settings, `[` copy mode, `e` edit scrollback, `b` sidebar, `o` open notification, `G` new worktree, `q` detach |

The last group are screens only herdr itself can open. They are shown dimmed as reminders; to use them,
press herdr's native prefix, then the key.

**This changes the user's prefix.** The popup is bound to plain `ctrl+b`, which is also herdr's default
prefix, so the config moves herdr's own prefix to `ctrl+alt+b`. Every default `prefix+...` binding keeps
working under the new prefix. Tell the user this before you change anything, and get their OK.

## Files in this package

| File | Goes to |
|---|---|
| `herdr/scripts/whichkey.py` | `~/.config/herdr/scripts/whichkey.py` (must be executable) |
| `herdr/config.snippet.toml` | merged into `~/.config/herdr/config.toml` (never replace that file) |

This is the author's daily setup on herdr 0.9.3 (macOS). The config was validated with `herdr config check`,
and the script's key handling was tested against a stub herdr CLI on Python 3.14.4. The herdr docs at the
time of writing describe 0.9.5.

## Rules for you, the agent

- Ask before writing to the user's herdr config. Back it up first.
- Never overwrite `config.toml` or an existing script without showing a diff and asking.
- Never copy, read aloud, or upload anything else from `~/.config/herdr/`. It holds session snapshots,
  logs and sockets that are private. This package contains only the two files above.
- Do not install anything (herdr, Python, fonts) without the user's consent. List what is missing and ask.
- If the environment variable `HERDR_ENV=1` is set, you are running inside a herdr pane and the user is
  attached. Never launch `herdr` from your shell, and never run `herdr server stop`.
- Do not press the menu's action keys in the user's live session as a test. They split, close and rename
  real panes. Use the safe preview in step 5.
- Do not commit anything or change git config on the user's behalf.
- Report what you changed and what you only suggested.

## 1. Preflight (read-only)

```sh
herdr --version             # herdr must be installed
python3 --version           # the script needs python3 on PATH; 3.11+ recommended (see below)
herdr status                # is a server running?
echo "${HERDR_ENV:-not inside herdr}"
echo "${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"   # the config file in use
cat "${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}" 2>/dev/null
ls -l ~/.config/herdr/scripts/ 2>/dev/null
```

Note from the output:

- Whether `config.toml` exists, and whether it already has a `[keys]` table, a custom `prefix`, or any
  `[[keys.command]]` entry that uses `ctrl+b`.
- Whether `~/.config/herdr/scripts/whichkey.py` already exists.
- Python version. Below 3.11 the script cannot read `config.toml`; it still works, but it assumes the native
  prefix is `ctrl+alt+b` in its hints and ignores the `[ui]` settings listed under "Customize".
- If `HERDR_CONFIG_PATH` is set, the script's own config lookup assumes `config.toml` sits one directory
  above `scripts/`. Install the script into `<that config's directory>/scripts/` and use that path in the
  popup `command`.

### If herdr is not installed

Stop and ask the user whether they want it installed. herdr's own agent guide
(https://herdr.dev/agent-guide.md) gives the official install command, `curl -fsSL https://herdr.dev/install.sh | sh`,
and lists Homebrew, mise and Nix as alternatives (https://herdr.dev/docs/install/). That command pipes a
script into a shell, so say so and run it only with their consent. Afterwards the user should launch `herdr`
themselves, because it is an interactive full-screen program.

### If python3 is missing

Ask before installing it (`brew install python` on macOS, `sudo apt install python3` on Debian/Ubuntu).

## 2. Install the script

```sh
mkdir -p ~/.config/herdr/scripts
cp herdr/scripts/whichkey.py ~/.config/herdr/scripts/whichkey.py
chmod +x ~/.config/herdr/scripts/whichkey.py
```

Copy the file; do not retype it. The menu icons are Nerd Font glyphs (private-use characters) that are easy
to corrupt when pasting. Check with `cmp herdr/scripts/whichkey.py ~/.config/herdr/scripts/whichkey.py`.

## 3. Merge the config

Back up first, using a timestamp like the user's own backups do:

```sh
cp ~/.config/herdr/config.toml ~/.config/herdr/config.toml.bak-$(date +%Y%m%d-%H%M%S)
```

(If there is no `config.toml` yet, herdr runs on built-in defaults. You can create one containing just the snippet.)

TOML rules that matter here:

- **Append at the end of the file.** Anything after a `[table]` header belongs to that table, so adding the
  snippet in the middle can silently move the user's top-level settings into `[keys]`.
- **Only one `[keys]` table is allowed.** If the user already has one, do not paste the snippet's `[keys]`
  header. Set `prefix` inside the existing table (ask first if they already chose a custom prefix) and
  append only the `[[keys.command]]` block at the end of the file.
- **A config that fails to parse means defaults.** For an unparseable `config.toml`, `herdr config check`
  reports `using defaults`, so expect the user's keybindings and settings to revert rather than an obvious
  crash. Always run step 4.
- If an existing `[[keys.command]]` already uses `ctrl+b`, ask the user which one wins.

### If the user does not want to give up `ctrl+b` as the prefix

Leave `prefix` alone and bind the popup to a prefix key instead. In `[[keys.command]]` use
`key = "prefix+<key>"`, for example `key = "prefix+space"`, with the same `type`, `command`, `description`,
`width` and `height`. Pick a key that herdr's defaults don't use (check `herdr --default-config`). `herdr config check`
accepts this form; I have not tried it in a running herdr. The script reads `prefix` from `config.toml` and
adapts its "via ..." hints automatically (Python 3.11+).

## 4. Validate and apply

```sh
herdr config check             # expect: "config: ok"
herdr server reload-config     # applies it to the running server, no restart needed
```

If `herdr config check` reports an error, restore the backup and fix the merge. A typical failure is
`duplicate key 'keys' in document root`, caused by pasting a second `[keys]` header.

## 5. Verify

Safe, read-only preview. It prints the menu and does not talk to herdr:

```sh
python3 ~/.config/herdr/scripts/whichkey.py --preview 130
```

Expect four groups (Panes, Tabs, Workspace, `via ctrl+alt+b`) and a footer line
`esc close   ctrl+alt+b + key for native screens`. Narrower widths (for example `--preview 70`) switch to a
flat multi-column layout automatically.

Then ask the user to press `ctrl+b` inside herdr (or the key you chose) and confirm that the popup opens and
`esc` closes it. Do not do this for them.

## Customize (suggest, do not apply unprompted)

| Goal | How |
|---|---|
| Hide the Nerd Font icons | Set the popup command to `HERDR_WHICHKEY_ICONS=0 exec "$HOME/.config/herdr/scripts/whichkey.py"` |
| Resize the popup | `width` / `height` in the `[[keys.command]]` entry. Numbers are terminal cells, strings like `"90%"` are percentages. |
| Match a different theme | The menu colors are Solarized hex values near the top of `whichkey.py` (`KEY`, `ARROW`, `TEXT`, `DIM`, `ALERT`) and in `GROUPS`. Edit those. |
| Add, remove or rename menu entries | Edit the `GROUPS` list in `whichkey.py`. Each entry maps a key to a herdr CLI call. |

Settings the script reads from `config.toml` when Python is 3.11+: `[keys] prefix` (for the hints), and in
`[ui]`: `confirm_close` (default true), `prompt_new_tab_name` (default true), `prompt_new_workspace_name`
(default false).

The menu's keys mirror herdr's **default** prefix bindings. If the user rebound those in `[keys]`, the menu
will not follow; edit `GROUPS` to match.

## Revert

Prefer restoring the backup you made in step 3, then run `herdr server reload-config`. Optionally delete
`~/.config/herdr/scripts/whichkey.py`.

`herdr config reset-keys` also works, but it removes **all** custom keybindings and `[[keys.command]]`
entries (it backs up `config.toml` first), not just this popup. Use it only if the user wants a full reset.

## Troubleshooting

- **`ctrl+b` still behaves like the old prefix:** the config was not reloaded or the merge failed. Run
  `herdr config check`, then `herdr server reload-config`.
- **Popup opens and closes immediately, or shows nothing:** run `python3 ~/.config/herdr/scripts/whichkey.py --preview 130`
  to see any Python error, and check the script is executable and the `command` path matches where it is installed.
- **Red error line inside the popup (such as `herdr pane split failed`):** the script calls herdr's CLI
  (`herdr pane|tab|workspace ...`). An older herdr may lack a subcommand. Update herdr (`herdr update`) or
  remove that entry from `GROUPS`.
- **Icons show as boxes or `?`:** the terminal font is not a Nerd Font. Install one or turn icons off (see Customize).
- **`ctrl+alt+b` does nothing:** the terminal may not be delivering that combination to herdr. On macOS,
  check the terminal's "Option as Alt" setting, or choose a different `prefix`. I have not verified this for
  every terminal.
- **Menu looks cramped:** increase the popup `width` and `height`.
