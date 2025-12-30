return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      codelens = {
        enabled = false,
      },
    },
    keys = {
      -- LazyVimのcodelensキーマップを無効化
      { "<leader>cc", false },
    },
  },
}