vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt

opt.relativenumber = true
opt.number = true

-- tab/index settings
opt.expandtab = true
opt.shiftround = true
opt.shiftwidth = 2
opt.softtabstop = 2
opt.autoindent = true
opt.tabstop = 2

opt.scrolloff = 3

opt.whichwrap = 'bshl<>[]~'

opt.wrap = false

-- search settings
opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

opt.backspace = "indent,eol,start"

-- share clipboard with OS 
opt.clipboard:append("unnamedplus,unnamed")

-- split windows
opt.splitright = true
opt.splitbelow = true
