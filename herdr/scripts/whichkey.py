#!/usr/bin/env python3
"""which-key style menu for herdr.

config.toml binds this to ctrl+b as a popup. Each key runs a herdr action
through the CLI, using the same keys as herdr's default prefix bindings, so
ctrl+b v still splits right. Screens the CLI can't open (goto, settings, copy
mode, ...) are listed under the native prefix and stay on herdr's own prefix.

  --preview [WIDTH]   print the menu instead of opening it
  HERDR_WHICHKEY_ICONS=0 hides the Nerd Font icons
"""

import collections
import json
import os
import select
import shutil
import subprocess
import sys
import termios
import tty

try:
    import tomllib
except ImportError:  # Python < 3.11 can't read config.toml; use the defaults
    tomllib = None

HERDR = os.environ.get("HERDR_BIN_PATH") or "herdr"
CONFIG_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config.toml"
)
ICONS = os.environ.get("HERDR_WHICHKEY_ICONS", "1") != "0"
DIRECTIONS = {"h": "left", "j": "down", "k": "up", "l": "right"}


def load_config():
    if tomllib is None:
        return {}
    try:
        with open(CONFIG_PATH, "rb") as f:
            return tomllib.load(f)
    except (OSError, ValueError):
        return {}


CONFIG = load_config()
UI = CONFIG.get("ui", {})
NATIVE_PREFIX = CONFIG.get("keys", {}).get("prefix") or "ctrl+alt+b"
if isinstance(NATIVE_PREFIX, list):
    NATIVE_PREFIX = NATIVE_PREFIX[0]


def fg(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return "\x1b[38;2;%d;%d;%dm" % (r, g, b)


# Solarized, to match theme.name in config.toml.
RESET, BOLD = "\x1b[0m", "\x1b[1m"
KEY, ARROW, TEXT, DIM, ALERT = (
    fg(c) for c in ("#b58900", "#586e75", "#93a1a1", "#586e75", "#dc322f")
)


# --- herdr ------------------------------------------------------------------

class HerdrError(Exception):
    pass


def herdr(*args):
    """Run a herdr CLI command and return the "result" object of its JSON reply."""
    proc = subprocess.run(
        [HERDR] + list(args),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    try:
        reply = json.loads(proc.stdout) if proc.stdout.strip() else {}
    except ValueError:
        reply = {}
    if proc.returncode != 0 or "error" in reply:
        message = reply.get("error", {}).get("message") or proc.stderr.strip()
        raise HerdrError(message or "herdr %s failed" % " ".join(args))
    return reply.get("result", {})


_active = None


def active():
    """(pane, tab, workspace) ids of the tiled pane underneath the popup."""
    global _active
    if _active is None:
        ids = [os.environ.get("HERDR_ACTIVE_%s_ID" % n) for n in ("PANE", "TAB", "WORKSPACE")]
        if all(ids):
            _active = tuple(ids)
        else:
            pane = herdr("pane", "current")["pane"]
            _active = (pane["pane_id"], pane["tab_id"], pane["workspace_id"])
    return _active


# --- actions ------------------------------------------------------------------

def split(direction):
    herdr("pane", "split", "--pane", active()[0], "--direction", direction, "--focus")


def focus(direction):
    herdr("pane", "focus", "--pane", active()[0], "--direction", direction)


def swap(direction):
    herdr("pane", "swap", "--pane", active()[0], "--direction", direction)


def zoom():
    herdr("pane", "zoom", "--pane", active()[0], "--toggle")


def resize():
    """Keep resizing the active pane with h/j/k/l until any other key."""
    while True:
        draw(message("Resize with h/j/k/l", "any other key to finish"))
        direction = DIRECTIONS.get(read_key().lower())
        if direction is None:
            return
        herdr("pane", "resize", "--pane", active()[0], "--direction", direction)


def rename_pane():
    pane_id = active()[0]
    current = herdr("pane", "get", pane_id)["pane"].get("label") or ""
    label = prompt("Rename pane", current)
    if label == "":
        herdr("pane", "rename", pane_id, "--clear")
    elif label is not None:
        herdr("pane", "rename", pane_id, label)


def close_pane():
    pane_id, _, workspace_id = active()
    workspace = herdr("workspace", "get", workspace_id)["workspace"]
    if workspace["pane_count"] <= 1 and UI.get("confirm_close", True):
        if not confirm("Close the workspace's only pane?"):
            return
    herdr("pane", "close", pane_id)


def workspace_tabs():
    tabs = herdr("tab", "list", "--workspace", active()[2])["tabs"]
    return sorted(tabs, key=lambda tab: tab["number"])


def cycle_tab(step):
    tabs = workspace_tabs()
    index = next((i for i, tab in enumerate(tabs) if tab["tab_id"] == active()[1]), 0)
    herdr("tab", "focus", tabs[(index + step) % len(tabs)]["tab_id"])


def goto_tab(number):
    for tab in workspace_tabs():
        if tab["number"] == number:
            herdr("tab", "focus", tab["tab_id"])


def new_tab():
    args = ["tab", "create", "--workspace", active()[2], "--focus"]
    if UI.get("prompt_new_tab_name", True):
        label = prompt("New tab name", "")
        if label is None:
            return
        if label:
            args += ["--label", label]
    herdr(*args)


def rename_tab():
    tab_id = active()[1]
    label = prompt("Rename tab", herdr("tab", "get", tab_id)["tab"]["label"])
    if label:
        herdr("tab", "rename", tab_id, label)


def close_tab():
    if len(workspace_tabs()) <= 1 and UI.get("confirm_close", True):
        if not confirm("Close the workspace's last tab?"):
            return
    herdr("tab", "close", active()[1])


def new_workspace():
    args = ["workspace", "create", "--focus"]
    if UI.get("prompt_new_workspace_name", False):
        label = prompt("New workspace name", "")
        if label is None:
            return
        if label:
            args += ["--label", label]
    herdr(*args)


def rename_workspace():
    workspace_id = active()[2]
    current = herdr("workspace", "get", workspace_id)["workspace"]["label"]
    label = prompt("Rename workspace", current)
    if label:
        herdr("workspace", "rename", workspace_id, label)


def close_workspace():
    workspace_id = active()[2]
    if UI.get("confirm_close", True):
        label = herdr("workspace", "get", workspace_id)["workspace"]["label"]
        if not confirm("Close workspace %s?" % label):
            return
    herdr("workspace", "close", workspace_id)


def reload_config():
    herdr("server", "reload-config")


def send_prefix():
    """ctrl+b ctrl+b passes a literal ctrl+b through to the pane, like tmux."""
    herdr("pane", "send-keys", active()[0], "ctrl+b")


# --- menu ---------------------------------------------------------------------

# keys is a string of single-character keys or a tuple of key names.
# An entry without an action is a native herdr screen, shown as a hint only.
Entry = collections.namedtuple("Entry", "label keys icon desc action")
Group = collections.namedtuple("Group", "title color entries")

GROUPS = [
    Group("Panes", "#268bd2", [
        Entry("v", "v", "", "Split right", lambda key: split("right")),
        Entry("-", "-", "", "Split down", lambda key: split("down")),
        Entry("hjkl", "hjkl", "", "Focus pane", lambda key: focus(DIRECTIONS[key])),
        Entry("HJKL", "HJKL", "", "Swap pane", lambda key: swap(DIRECTIONS[key.lower()])),
        Entry("z", "z", "", "Zoom", lambda key: zoom()),
        Entry("r", "r", "", "Resize mode", lambda key: resize()),
        Entry("P", "P", "", "Rename pane", lambda key: rename_pane()),
        Entry("x", "x", "", "Close pane", lambda key: close_pane()),
    ]),
    Group("Tabs", "#6c71c4", [
        Entry("c", "c", "", "New tab", lambda key: new_tab()),
        Entry("n", "n", "", "Next tab", lambda key: cycle_tab(1)),
        Entry("p", "p", "", "Previous tab", lambda key: cycle_tab(-1)),
        Entry("1-9", "123456789", "", "Go to tab", lambda key: goto_tab(int(key))),
        Entry("T", "T", "", "Rename tab", lambda key: rename_tab()),
        Entry("X", "X", "", "Close tab", lambda key: close_tab()),
    ]),
    Group("Workspace", "#859900", [
        Entry("N", "N", "", "New workspace", lambda key: new_workspace()),
        Entry("W", "W", "", "Rename workspace", lambda key: rename_workspace()),
        Entry("D", "D", "", "Close workspace", lambda key: close_workspace()),
        Entry("R", "R", "", "Reload config", lambda key: reload_config()),
        Entry("C-b", ("ctrl+b",), "", "Send ctrl+b", lambda key: send_prefix()),
    ]),
    # herdr's default prefix bindings for screens only herdr itself can open.
    Group("via " + NATIVE_PREFIX, "#586e75", [
        Entry("g", "g", "", "Go to agent", None),
        Entry("w", "w", "", "Workspaces", None),
        Entry("?", "?", "", "All keybindings", None),
        Entry("s", "s", "", "Settings", None),
        Entry("[", "[", "", "Copy mode", None),
        Entry("e", "e", "", "Edit scrollback", None),
        Entry("b", "b", "", "Toggle sidebar", None),
        Entry("o", "o", "", "Open notification", None),
        Entry("G", "G", "", "New worktree", None),
        Entry("q", "q", "", "Detach", None),
    ]),
]

BINDINGS = {key: entry for group in GROUPS for entry in group.entries for key in entry.keys}
GAP = 3


def cell_text(entry):
    icon = entry.icon + " " if ICONS else ""
    return "%4s → %s%s" % (entry.label, icon, entry.desc)


def cell(entry, color, width):
    """One "key → icon description" cell, padded to width columns."""
    pad = " " * (width - len(cell_text(entry)))
    if entry.action is None:
        return DIM + cell_text(entry) + RESET + pad
    icon = fg(color) + entry.icon + " " if ICONS else ""
    return (BOLD + KEY + "%4s" % entry.label + RESET + ARROW + " → " + icon
            + TEXT + entry.desc + RESET + pad)


def grouped(col):
    """One column per group, each under its title."""
    lines = ["".join(BOLD + fg(g.color) + ("  " + g.title).ljust(col) + RESET for g in GROUPS)]
    for row in range(max(len(g.entries) for g in GROUPS)):
        lines.append("".join(
            cell(g.entries[row], g.color, col) if row < len(g.entries) else " " * col
            for g in GROUPS
        ))
    return lines, len(GROUPS)


def flat(col, width, height):
    """Narrow popups: all entries in as many columns as fit, without titles."""
    cells = [(entry, g.color) for g in GROUPS for entry in g.entries]
    cols = max(1, width // col)
    if -(-len(cells) // cols) > height:  # too tall: drop the native hints first
        cells = [c for c in cells if c[0].action is not None]
    rows = -(-len(cells) // cols)
    lines = ["".join(cell(e, color, col) for e, color in cells[row::rows]) for row in range(rows)]
    return lines, -(-len(cells) // rows)


def menu_lines(width, height, status=None):
    col = max(len(cell_text(e)) for g in GROUPS for e in g.entries) + GAP
    if col * len(GROUPS) - GAP <= width:
        body, cols = grouped(col)
    else:
        body, cols = flat(col, width, height - 3)
    left = " " * max(0, (width - (col * cols - GAP)) // 2)
    text, color = status or ("esc close   %s + key for native screens" % NATIVE_PREFIX, DIM)
    return [""] + [left + line for line in body] + ["", color + text.center(width).rstrip() + RESET]


def message(title, hint):
    width = shutil.get_terminal_size().columns
    return ["", "  " + BOLD + KEY + title + RESET, "", DIM + hint.center(width).rstrip() + RESET]


# --- terminal -----------------------------------------------------------------

NAMED_KEYS = {
    b"\x1b": "esc", b"\x03": "esc", b"\x02": "ctrl+b", b"\r": "enter", b"\n": "enter",
    b"\x7f": "backspace", b"\x08": "backspace", b"\x15": "ctrl+u",
}


def read_key():
    """Read one keypress: a character, a name from NAMED_KEYS, or "" to ignore."""
    fd = sys.stdin.fileno()
    data = os.read(fd, 1)
    if data == b"\x1b" and select.select([fd], [], [], 0.03)[0]:
        os.read(fd, 64)  # an escape sequence such as an arrow key
        return ""
    if data in NAMED_KEYS:
        return NAMED_KEYS[data]
    if data and data[0] >= 0xC0:  # UTF-8 lead byte: read the rest of the character
        data += os.read(fd, 1 + (data[0] >= 0xE0) + (data[0] >= 0xF0))
    return data.decode("utf-8", "ignore")


def draw(lines):
    sys.stdout.write("\x1b[H\x1b[2J" + "\r\n".join(lines))
    sys.stdout.flush()


def prompt(title, text):
    """Edit a line of text inside the popup. Returns None on Esc."""
    while True:
        draw(message(title + ": " + RESET + text + "\x1b[7m \x1b[0m", "enter confirm   esc cancel"))
        key = read_key()
        if key == "esc":
            return None
        if key == "enter":
            return text.strip()
        if key == "backspace":
            text = text[:-1]
        elif key == "ctrl+u":
            text = ""
        elif len(key) == 1 and key.isprintable():
            text += key


def confirm(question):
    draw(message(question, "y confirm   any other key cancels"))
    return read_key() in ("y", "Y")


def run(entry, key):
    try:
        entry.action(key)
    except HerdrError as error:
        draw(message(ALERT + str(error), "press any key"))
        read_key()


def main():
    if "--preview" in sys.argv:
        rest = sys.argv[sys.argv.index("--preview") + 1:]
        width = int(rest[0]) if rest else shutil.get_terminal_size().columns
        print("\n".join(menu_lines(width, 40)))
        return

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    tty.setraw(fd)
    sys.stdout.write("\x1b[?25l")
    try:
        status = None
        while True:
            size = shutil.get_terminal_size()
            draw(menu_lines(size.columns, size.lines, status))
            key = read_key()
            if not key:
                continue
            entry = BINDINGS.get(key)
            if entry is None:  # esc, or an unmapped key, closes the menu
                return
            if entry.action is None:
                status = ("%s: press %s then %s" % (entry.desc, NATIVE_PREFIX, key), KEY)
                continue
            run(entry, key)
            return
    finally:
        sys.stdout.write(RESET + "\x1b[2J\x1b[H\x1b[?25h")
        sys.stdout.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)


if __name__ == "__main__":
    main()
