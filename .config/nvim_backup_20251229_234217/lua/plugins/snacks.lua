return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    opts = {
      picker = {
        hidden = true,
        ignore = true,
      },
    },
    exploer = {
      hidden = true,
      ignore = true,
      filters = {
        dotfiles = true,
        gitignored = true,
      },
    },
  },
}
