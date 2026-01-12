return {
  "zbirenbaum/copilot.lua",
  enabled = true,
  cmd = { "Copilot" },
  event = { "InsertEnter", "VeryLazy" },
  opts = {
    suggestion = {
      enabled = true,
      auto_trigger = true,
      keymap = {
        accept = "<C-s>",
        accept_word = false,
        accept_line = false,
        next = "<C-n>",
        prev = false,
        dismiss = "<C-l>",
      },
    },
    filetypes = {
      TeleScopePrompt = false,
      ["*"] = true,
    }
  },
  config = function(_, opts)
    vim.defer_fn(function ()
      require("copilot").setup(opts)
    end, 100)
  end,
}
