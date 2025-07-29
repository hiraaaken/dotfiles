-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "jj", "<ESC>", { desc = "Exit insert mode" })

-- タブ移動
vim.keymap.set("n", "gt", "<cmd>bnext<cr>", { desc = "Next Buffer" })
vim.keymap.set("n", "gT", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
