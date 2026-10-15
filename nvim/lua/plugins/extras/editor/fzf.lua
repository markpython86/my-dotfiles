return {
  { import = "lazyvim.plugins.extras.editor.fzf" },
  {
    "fzf-lua",
    opts = {
      defaults = {
        -- hide the "<alt-h> to Exclude hidden files|..." hint line
        no_header_i = true,
      },
      winopts = {
        preview = {
          -- the file name is already in the list, so drop it from the preview border
          title = false,
          -- default is 60%, which squeezes the results list and truncates long paths
          horizontal = "right:50%",
        },
      },
      files = {
        -- exclude hidden files by default, <alt-h> toggles them on
        hidden = false,
      },
      file_ignore_patterns = {
        ".git/",
        -- node
        "node_modules/",
        -- rust
        "**/debug/",
        "target/release/",
        -- yarn
        ".yarn/*",
      },
      oldfiles = {
        cwd_only = true,
      },
      buffer = {
        cwd_only = true,
      },
      grep = {
        multiline = 1,
      },
    },
  },
}
