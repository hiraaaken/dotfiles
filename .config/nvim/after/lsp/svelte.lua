return {
  on_attach = function(client, bufnr)
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = {"*.js", "*.ts"},
      callback = function(ctx)
        client.notify("$/onDidChangeTsOrJsFile", {url = ctx.match })
      end,
    })
  end,
}
