return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa",
    },
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        transparent = true,
        dimInactive = false,
        terminalColors = true,
        colors = {
          theme = {
            all = {
              ui = {
                bg_gutter = "none", -- 行番号の背景を透明に
              },
            },
          },
        },
        overrides = function(colors)
          local theme = colors.theme
          return {
            -- 基本背景
            Normal = { bg = "none" },
            NormalNC = { bg = "none" },
            NormalFloat = { bg = "none" },
            FloatBorder = { bg = "none" },
            FloatTitle = { bg = "none" },

            -- サイドバー
            NeoTreeNormal = { bg = "none" },
            NeoTreeNormalNC = { bg = "none" },
            NeoTreeEndOfBuffer = { bg = "none" },

            -- コマンドライン関連（全部追加）
            MsgArea = { bg = "none" },
            MsgSeparator = { bg = "none" },

            -- ステータスライン・タブライン
            StatusLine = { bg = "none" },
            StatusLineNC = { bg = "none" },
            TabLine = { bg = "none" },
            TabLineFill = { bg = "none" },
            TabLineSel = { bg = "none" },

            -- ポップアップメニュー
            Pmenu = { bg = "none" },
            PmenuSel = { bg = "none" },
            PmenuSbar = { bg = "none" },
            PmenuThumb = { bg = "none" },

            -- Telescope
            TelescopeNormal = { bg = "none" },
            TelescopeBorder = { bg = "none" },
            TelescopePromptNormal = { bg = "none" },
            TelescopePromptBorder = { bg = "none" },
            TelescopeResultsNormal = { bg = "none" },
            TelescopeResultsBorder = { bg = "none" },
            TelescopePreviewNormal = { bg = "none" },
            TelescopePreviewBorder = { bg = "none" },
          }
        end,
      })
      vim.cmd.colorscheme("kanagawa")
    end,
  },
}
