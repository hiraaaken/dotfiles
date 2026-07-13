return {
  "stevearc/oil.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "refractalize/oil-git-status.nvim",
  },
  lazy = false,
  keys = {
    {
      "<leader>e",
      function()
        require("oil").open_float()
      end,
    }
  },
  opts = {
    float = {
      padding = 2,
      max_width = 90,
      max_height = 30,
      border = "rounded",
      win_options = {
        winblend = 0,
      },
    },
    keymaps = {
				["?"] = "actions.show_help",
				["gx"] = "actions.open_external",
				["<CR>"] = "actions.select",
				["-"] = "actions.parent",
				["<C-p>"] = "actions.preview",
				["<esc>"] = "actions.close",
				["q"] = nil,
				["<C-l>"] = "actions.refresh",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = "actions.tcd",
				["g."] = "actions.toggle_hidden",
				["<C-s>"] = "actions.select_vsplit",
				["<C-h>"] = "actions.select_split",
				["<C-t>"] = "actions.select_tab",
    },
    default_file_explorer = true,
    view_options = { 
      show_hidden = true,
      is_always_hidden = function(name, _)
        local ignore_list = { ".DS_Store" }
        return vim.tbl_contains(ignore_list, name)
      end,
    },
    skip_confirm_for_simple_edits = true,
    delete_to_trash = true,
    win_options = {
      signcolumn = "yes:2",
    },
    lsp_file_methods = {
      enabled = true,
      timeout_ms = 1000,
      autosave_changes = false,
    }
  },
  config = function(_, opts)
    require('oil').setup(opts)
    require("oil-git-status").setup()
  end,
}
