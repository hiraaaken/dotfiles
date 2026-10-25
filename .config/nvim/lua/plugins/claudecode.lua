--- devcontainer プロジェクトではコンテナ内の Claude、それ以外はホストの Claude を開く
local function claude(args)
  local dc = require("devcontainer.claude")
  if dc.in_container_project() then return dc.open_current(args) end
  vim.cmd({ cmd = "ClaudeCode", args = args })
end

return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {},
  config = function(_, opts)
    require("claudecode").setup(opts)
    -- devcontainer プロジェクトではホストの Claude を起動させない
    require("devcontainer.claude").guard_host_commands()
  end,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", function() claude({}) end, desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>ar", function() claude({ "--resume" }) end, desc = "Resume Claude" },
    { "<leader>aC", function() claude({ "--continue" }) end, desc = "Continue Claude" },
    { "<leader>aA", "<cmd>DevcontainerAgent<cr>", desc = "Claude agent mode (container)" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
    },
    -- Diff management
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
}
