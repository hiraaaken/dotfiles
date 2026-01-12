vim.g.mapleader = " "

local keymap = vim.keymap

keymap.set("i", "jj", "<ESC>", { desc = "Exit insert mode with jj" })

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- window move
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to down window' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to up window' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })

-- tab move
vim.keymap.set('n', 'H', '<CMD>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', 'L', '<CMD>bnext<CR>', { desc = 'Next buffer' })

-- cursor move
keymap.set({ "n", "x" }, "<leader>h", "^", { desc = "Move to the beggining of the line" })
keymap.set({ "n", "x" }, "<leader>l", "$", { desc = "Move to the end of the line" })

-- paste
vim.keymap.set("n", "p", "p`]", { desc = "Paste and move to the end" })
vim.keymap.set("n", "P", "P`]", { desc = "Paste and move to the end" })
vim.keymap.set("x", "p", "P", { desc = "Paste without change register" })
vim.keymap.set("x", "P", "p", { desc = "Paste with change register" })

-- delete
vim.keymap.set('n', 'x', '"_x', { desc = 'Delete char without yanking' })
vim.keymap.set('x', 'x', '"_d', { desc = 'Delete selection without yanking' })
vim.keymap.set('o', 'x', 'd',   { desc = 'Use x as delete operator' })

-- Ex command
vim.keymap.set('n', '<leader>;', '@:', { desc = 'Re-run the last command' })
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Write' })
vim.keymap.set({ 'n', 'x' }, 'so', ':source<cr>', { silent = true, desc = 'Source current script' })

-- commandline history
vim.keymap.set("c", "<c-n>", function()
  return vim.fn.wildmenumode() == 1 and "<c-n>" or "<down>"
end, { expr = true, desc = "Select next" })
vim.keymap.set("c", "<c-p>", function()
  return vim.fn.wildmenumode() == 1 and "<c-p>" or "<up>"
end, { expr = true, desc = "Select previous" })

-- close
vim.keymap.set("n", "<leader>q", function()
  local bd = require("mini.bufremove").delete

  if vim.bo.modified then
    local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname()), "&Yes¥n&No¥n&Cancel")
    if choice == 1 then vim.cmd("write") end
    if choice == 3 then return end
  end

  bd(0, false)

  local bufs = vim.fn.getbufinfo({ buflisted = 1 })

  if #bufs == 0 or (#bufs == 1 and bufs[1].name == "") then
    Snacks.dashboard.open()
  end
end, { desc = "Delete buffer and show dashboard if empty" })
vim.keymap.set("n", "<leader>Q", function()
  vim.cmd("quit")
end, { desc = "Close window / Quit" })
