return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = {
    spec = {
      { "<leader>t", group = "terminal" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({global = false})
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
