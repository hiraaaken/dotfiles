return {
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        compile = false,
        undercurl = true,
        commentStyle = { italic = true },
        functionStyle = {},
        keywordStyle = { italic = true },
        statementStyle = { bold = true },
        typeStyle = {},
        transparent = true,
        dimInactive = false,
        terminalColors = true,
        colors = {
          palette = {},
          theme = { wave = {}, lotus = {}, dragon = {}, all = {} }
        },
        theme = "wave",
        background = {
          dark = "wave",
          light = "lotus"
        },
      })
      vim.cmd([[colorscheme kanagawa]])

      -- Dashboard header color override
      vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#dca561", bold = true })
    end,
  },
}
