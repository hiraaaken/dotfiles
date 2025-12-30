-- markdownファイルでのスペルチェックを無効化
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = false
  end,
})
