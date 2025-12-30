vim.keymap.set("i", "jj", "<ESC>", { desc = "Exit insert mode" })

-- タブ移動
vim.keymap.set("n", "gt", "<cmd>bnext<cr>", { desc = "Next Buffer" })
vim.keymap.set("n", "gT", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })

-- カーソル移動
vim.keymap.set("n", "<leader>h", "^", { desc = "Move to the beginning of the line" })
vim.keymap.set("n", "<leader>l", "$", { desc = "Move to the end of the line" })

-- ウィンドウ分割
vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
