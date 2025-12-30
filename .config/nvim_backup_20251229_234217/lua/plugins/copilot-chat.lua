return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary", 
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    build = "make tiktoken", -- tiktoken のビルドが必要
    opts = {
      debug = true, -- デバッグ有効化
      auto_follow_cursor = false,
      auto_insert_mode = true, -- 自動でインサートモード
      show_help = "yes", -- ヘルプ表示
      window = {
        layout = 'vertical', -- 垂直分割に変更
        width = 0.4, -- 画面の40%の幅
        height = 1.0, -- フルハイト
        relative = 'editor',
        row = 0,
        col = '100%', -- 右端に配置
      },
    },
    keys = {
      {
        "<leader>ch",
        "<cmd>CopilotChat<CR>",
        desc = "CopilotChat - Open",
      },
      {
        "<leader>cc",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input)
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      chat.setup(opts)
    end,
  },
}