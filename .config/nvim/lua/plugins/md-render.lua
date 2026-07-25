return {
  {
    "delphinus/md-render.nvim",
    version = "*",
    dependencies = {
      { "nvim-tree/nvim-web-devicons", version = "*" },
      { "delphinus/budoux.lua", version = "*" },
    },
    cmd = { "MdRender", "MdRenderTab", "MdRenderPager", "MdRenderDemo" },
    keys = {
      { "<leader>mr", "<Plug>(md-render-preview)", desc = "Markdown render preview (toggle)" },
      { "<leader>mt", "<Plug>(md-render-preview-tab)", desc = "Markdown render preview in tab (toggle)" },
      { "<leader>md", "<Plug>(md-render-demo)", desc = "Markdown render demo" },
    },
  },
}
