-- JetBrains 公式 Kotlin LSP (kotlin_lsp) のラッパー
-- 補完アイテムの insertText が正しく反映されない不具合の修正、
-- import 自動整理、inlay hints、コードフォールディングなどを追加する
return {
  "AlexandrosAlexiou/kotlin.nvim",
  ft = { "kotlin" },
  dependencies = {
    "mason.nvim",
    "mason-lspconfig.nvim",
    "oil.nvim",
    "folke/trouble.nvim",
  },
  config = function()
    require("kotlin").setup({
      jdk_for_symbol_resolution = nil, -- 自動検出
      jvm_args = { "-Xmx4g" },
      inlay_hints = { enabled = true },
      folding = { enabled = true },
    })
  end,
}
