local augroup = vim.api.nvim_create_augroup('init.lua', {})

local function create_autocmd(event, opts)
  vim.api.nvim_create_autocmd(event, vim.tbl_extend('force', {
    group = augroup,
  }, opts))
end

-- ファイル保存時に存在しないディレクトリを作成
--https://vim-jp.org/vim-users-jp/2011/02/20/Hack-202.html
create_autocmd('BufWritePre', {
  pattern = '*',
  callback = function(event)
    local dir = vim.fs.dirname(event.file)
    local force = vim.v.cmdbang == 1
    if vim.fn.isdirectory(dir) == 0
        and (force or vim.fn.confirm('"' .. dir .. '" does not exist. Create?', "&Yes\n&No") == 1) then
      vim.fn.mkdir(vim.fn.iconv(dir, vim.opt.encoding:get(), vim.opt.termencoding:get()), 'p')
    end
  end,
  desc = 'Auto mkdir to save file'
})

-- ディレクトリを引数で開いた場合、dashboard + oil.nvim float を表示
create_autocmd('VimEnter', {
  callback = function()
    local arg = vim.fn.argv(0)
    -- ディレクトリを引数で開いた場合
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.cmd("cd " .. vim.fn.fnameescape(arg))
      require("snacks").dashboard()
      -- 少し遅延させてフローティングで開く
      vim.schedule(function()
        require("oil").open_float()
      end)
    end
  end,
  desc = 'Open dashboard and oil.nvim float when opening a directory'
})
