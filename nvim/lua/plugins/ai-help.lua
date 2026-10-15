-- ai-help: ask "how do I ... in neovim?" and get keystrokes for THIS config.
-- Pure local Lua (lua/util/ai_help). Uninstall: delete this file and lua/util/ai_help/.
-- Config via `vim.g.ai_help` (see lua/util/ai_help/README.md).
return {
  {
    "which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "+ai" },
      },
    },
  },

  {
    name = "ai-help",
    dir = vim.fn.stdpath("config") .. "/lua/util/ai_help",
    cmd = "AiHelp",
    keys = {
      {
        "<leader>ai",
        function()
          require("util.ai_help").start(nil, false)
        end,
        mode = "n",
        desc = "Ask how to do X",
      },
      {
        "<leader>ai",
        function()
          require("util.ai_help").start(nil, true)
        end,
        mode = "x",
        desc = "Ask how to do X (selection)",
      },
    },
    config = function()
      require("util.ai_help").setup()
    end,
  },
}
