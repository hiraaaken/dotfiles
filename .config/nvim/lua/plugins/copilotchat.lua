return {
  "CopilotC-Nvim/CopilotChat.nvim",
  event = "VeryLazy",
  buiild = "make tiktoken",
  keys = {
    { "cpc", "CopilotChat", mode = "ca" },
  },
  dependencies = {
    "zbirenbaum/copilot.lua",
    "nvim-lua/plenary.nvim",
  },
  opts = {
    debug = false,
    chat_autocomplete = true,
  },
}
