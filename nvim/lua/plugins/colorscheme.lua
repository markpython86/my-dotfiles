return {
  { "catppuccin", enabled = false },

  {
    "f-person/auto-dark-mode.nvim",
    event = "VeryLazy",
    opts = {
      update_interval = 1000,
      set_dark_mode = function()
        vim.o.background = "dark"
      end,
      set_light_mode = function()
        vim.o.background = "light"
      end,
    },
  },

  {
    "tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
      },
      -- neo-tree's unstaged/conflict groups are italic by default; the font has no italic face,
      -- so the terminal slants the glyph and the unstaged checkbox renders as a parallelogram
      on_highlights = function(hl)
        hl.NeoTreeGitUnstaged = { fg = "#ff8700", bold = true }
        hl.NeoTreeGitConflict = { fg = "#ff8700", bold = true }
      end,
    },
  },
}
