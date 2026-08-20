return {
  "williamboman/mason-lspconfig.nvim",
  opts = {
    -- kotlin_lsp は kotlin.nvim が設定してから起動する必要があるため自動起動から除外
    automatic_enable = { exclude = { "kotlin_lsp" } },
    ensure_installed = {
      "ts_ls",
      "html",
      "cssls",
      "tailwindcss",
      "svelte",
      "lua_ls",
      "graphql",
      "emmet_ls",
      "prismals",
      "pyright",
      "eslint",
      "kotlin_lsp",
    },
  },
  dependencies = {
    {
      "williamboman/mason.nvim",
      opts = {
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      },
    },
    "neovim/nvim-lspconfig",
  },
}
