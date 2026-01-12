return {
  settings = {
    Lua = {
      diagnostics = {
        globals = {"Snacks"},
      },
      workspace = {
        library = {
          vim.env.VIMRUNTIME .. "/lua",
        }
      }
    }
  }
}
