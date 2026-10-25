-- ターミナル（T1〜T6）。右の列（ターミナルのペイン）にターミナルを開く。
-- ペインの中ではバッファのようにターミナルを追加・切り替えでき、上下に分割できる。
-- 浮動ウィンドウだとエディタを操作できないので、分割にする
local project = require("devcontainer.project")

local M = {}

--- ペインの幅（画面に対する割合）
M.width = 0.4

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devcontainer" })
end

---@class devcontainer.TermSpec
---@field cmd string[]
---@field cwd string
---@field name string ペインの上の一覧に出す名前
---@field key? string 同じ key のターミナルがあれば、新しく開かずにそれを使う
---@field on_exit? fun(code: integer)

local count = 0

--- ペインに開いているターミナルのバッファ（開いた順）
---@return integer[]
local function terms()
  local list = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_valid(b) and vim.b[b].devcontainer_term ~= nil
  end, vim.api.nvim_list_bufs())
  table.sort(list, function(a, b) return vim.b[a].devcontainer_term.n < vim.b[b].devcontainer_term.n end)
  return list
end

---@param buf integer
local function alive(buf)
  local job = vim.b[buf].terminal_job_id
  return job and vim.fn.jobwait({ job }, 0)[1] == -1
end

---@param win integer
local function is_pane(win)
  return vim.api.nvim_win_is_valid(win) and vim.b[vim.api.nvim_win_get_buf(win)].devcontainer_term ~= nil
end

--- いまのタブで、ターミナルを表示しているウィンドウ
---@return integer[]
local function pane_wins()
  return vim.tbl_filter(is_pane, vim.api.nvim_tabpage_list_wins(0))
end

---@param key string
---@return integer?
local function find(key)
  for _, b in ipairs(terms()) do
    if vim.b[b].devcontainer_term.key == key and alive(b) then return b end
  end
end

--- ペインの上に出すターミナルの一覧（いま表示しているものを強調する）
function M.winbar()
  local cur = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local items = {}
  for i, b in ipairs(terms()) do
    local label = (" %d:%s%s "):format(i, vim.b[b].devcontainer_term.name, alive(b) and "" or " (終了)")
    table.insert(items, (b == cur and "%#TabLineSel#" or "%#TabLine#") .. label)
  end
  return table.concat(items) .. "%#TabLineFill#"
end

---@param win integer
local function setup_win(win)
  local wo = vim.wo[win]
  wo.number, wo.relativenumber, wo.signcolumn = false, false, "no"
  wo.winfixwidth = true
  wo.winbar = "%{%v:lua.require'devcontainer.terminal'.winbar()%}"
end

--- ターミナルを閉じたあとの後始末。表示していたウィンドウには別のターミナルを出し、無ければ閉じる
---@param buf integer
local function remove(buf)
  local others = vim.tbl_filter(function(b) return b ~= buf end, terms())
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    local shown = vim.tbl_map(vim.api.nvim_win_get_buf, pane_wins())
    local next_buf = vim.iter(others):find(function(b) return not vim.tbl_contains(shown, b) end)
    if next_buf then
      vim.api.nvim_win_set_buf(win, next_buf)
    elseif #vim.api.nvim_tabpage_list_wins(0) > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
end

--- win に新しいターミナルを開く
---@param win integer
---@param spec devcontainer.TermSpec
---@return integer buf
local function spawn(win, spec)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_win_set_buf(win, buf)
  count = count + 1
  vim.b[buf].devcontainer_term = { n = count, name = spec.name, key = spec.key }
  vim.api.nvim_win_call(win, function()
    vim.fn.jobstart(spec.cmd, {
      term = true,
      cwd = spec.cwd,
      on_exit = function(_, code)
        vim.schedule(function()
          if spec.on_exit then spec.on_exit(code) end
          -- 正常に終わったら閉じる。異常終了はメッセージを読めるよう残す（<leader>tx で閉じる）
          if code == 0 then remove(buf) end
          vim.cmd.redrawstatus({ bang = true })
        end)
      end,
    })
  end)
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      if alive(buf) then vim.cmd.startinsert() end
    end,
  })
  setup_win(win)
  return buf
end

--- ペインのウィンドウ。無ければ右に作る
---@return integer win, boolean created
local function ensure_pane()
  local cur = vim.api.nvim_get_current_win()
  if is_pane(cur) then return cur, false end
  local wins = pane_wins()
  if #wins > 0 then return wins[1], false end
  local editor = cur
  vim.cmd(("botright vertical %dsplit"):format(math.floor(vim.o.columns * M.width)))
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(editor)
  return win, true
end

---@param win integer
---@param focus? boolean
local function enter(win, focus)
  if focus == false then return end
  vim.api.nvim_set_current_win(win)
  if alive(vim.api.nvim_win_get_buf(win)) then vim.cmd.startinsert() end
end

--- ターミナルをペインに開く。spec.key のターミナルが既にあれば、それを表示する
---@param spec devcontainer.TermSpec
---@param opts? { focus?: boolean, new_window?: boolean } focus: カーソルを移す（既定 true）。new_window: ペインを上下に分割して開く
---@return integer buf, boolean created
function M.open(spec, opts)
  opts = opts or {}
  local existing = spec.key and find(spec.key)
  if existing then
    local win = vim.fn.win_findbuf(existing)[1]
    if not win then
      win = ensure_pane()
      vim.api.nvim_win_set_buf(win, existing)
      setup_win(win)
    end
    enter(win, opts.focus)
    return existing, false
  end
  local win, created = ensure_pane()
  if opts.new_window and not created then
    win = vim.api.nvim_win_call(win, function()
      vim.cmd("belowright split")
      return vim.api.nvim_get_current_win()
    end)
  end
  local buf = spawn(win, spec)
  enter(win, opts.focus)
  return buf, true
end

--- コンテナ内でログインシェルを起動するコマンド（zsh → bash → sh の順で探す）。
--- プロジェクトの node_modules/.bin（vp など）をそのまま使えるよう、PATH の先頭に足す
---@param p devcontainer.Project
function M.container_cmd(p)
  return {
    "docker", "exec", "-it",
    "-w", p.root,
    "-u", p.remote_user or "root",
    p.container_id,
    "sh", "-c", 'PATH="$1/node_modules/.bin:$PATH" exec $(command -v zsh || command -v bash || echo sh) -l', "sh", p.root,
  }
end

---@param p devcontainer.Project
---@param key? string
---@return devcontainer.TermSpec
local function container_spec(p, key)
  return { cmd = M.container_cmd(p), cwd = p.root, name = "shell", key = key }
end

---@param key? string
---@return devcontainer.TermSpec
local function host_spec(key)
  return { cmd = { vim.o.shell }, cwd = vim.fn.getcwd(), name = "host", key = key }
end

--- いまのバッファの devcontainer プロジェクト（コンテナを使う、または未回答）。管理外なら nil
---@return devcontainer.Project?
local function current_project()
  if not require("devcontainer").enabled then return end
  local p = project.for_buf(0)
  if not p then
    local root = project.find_root(vim.fn.getcwd())
    p = root and project.get(root)
  end
  if p and p.mode ~= "host" then return p end
end

--- 場所に応じたシェル（devcontainer プロジェクトはコンテナ、それ以外はホスト）を開く。準備中なら待つ
---@param new boolean 既存のシェルを使わず、新しく開く
---@param opts? { new_window?: boolean }
local function shell(new, opts)
  local p = current_project()
  if not p then return M.open(host_spec(not new and "host:" .. vim.fn.getcwd() or nil), opts) end
  require("devcontainer").when_ready(p, function()
    M.open(container_spec(p, not new and "shell:" .. p.root or nil), opts)
  end)
end

--- 新しいターミナルをペインに開く（場所に応じてコンテナかホスト）
---@param opts? { new_window?: boolean } new_window: ペインを上下に分割して開く
function M.new(opts)
  shell(true, opts)
end

function M.host()
  M.open(host_spec("host:" .. vim.fn.getcwd()))
end

--- コンテナのシェル。準備中なら待ってから開く（ホストにはフォールバックしない）
---@param p? devcontainer.Project
function M.container(p)
  p = p or current_project()
  if not p then return notify("devcontainer のプロジェクトではありません", vim.log.levels.WARN) end
  require("devcontainer").when_ready(p, function() M.open(container_spec(p, "shell:" .. p.root)) end)
end

--- コンテナの準備ができたときに、右にコンテナのシェルを開く。カーソルはエディタに残す
---@param p devcontainer.Project
function M.open_beside(p)
  M.open(container_spec(p, "shell:" .. p.root), { focus = false })
end

--- ペインのターミナルを順に切り替える
---@param step integer
function M.cycle(step)
  local list = terms()
  local cur = vim.api.nvim_get_current_buf()
  local i = vim.fn.index(list, cur)
  if i < 0 or #list < 2 then return end
  vim.api.nvim_win_set_buf(0, list[(i + step) % #list + 1])
end

--- いまのターミナルを閉じる（シェルも終わらせる）
function M.close()
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].devcontainer_term == nil then return end
  if alive(buf) then vim.fn.jobstop(vim.b[buf].terminal_job_id) end
  remove(buf)
end

--- ペインを閉じる（ターミナルは裏で動き続ける）
function M.hide()
  for _, win in ipairs(pane_wins()) do
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then pcall(vim.api.nvim_win_close, win, false) end
  end
end

--- ターミナルからエディタに戻る（ペインは残す）
function M.leave()
  vim.cmd.stopinsert()
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev == 0 or is_pane(prev) then
    prev = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(w) return not is_pane(w) end)
  end
  if prev then vim.api.nvim_set_current_win(prev) end
end

--- <C-/>: エディタからはペインに移る（無ければ場所に応じたシェルを開く）。ターミナルからはエディタに戻る
function M.auto()
  if is_pane(vim.api.nvim_get_current_win()) then return M.leave() end
  local wins = pane_wins()
  if #wins > 0 then return enter(wins[1]) end
  -- 閉じたペインに、最後に使っていたターミナルを出す
  local list = vim.tbl_filter(alive, terms())
  if #list > 0 then
    local win = ensure_pane()
    vim.api.nvim_win_set_buf(win, list[#list])
    setup_win(win)
    return enter(win)
  end
  shell(false)
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<C-/>", M.auto, { desc = "Terminal (container / host)" })
  map("n", "<C-_>", M.auto, { desc = "which_key_ignore" })
  map("n", "<leader>tn", function() M.new() end, { desc = "New terminal" })
  map("n", "<leader>ts", function() M.new({ new_window = true }) end, { desc = "New terminal (split)" })
  map("n", "<leader>tq", M.hide, { desc = "Hide terminals" })
  map("n", "<leader>tx", M.close, { desc = "Close terminal" })
  map("n", "<leader>th", M.host, { desc = "Terminal (host)" })
  map("n", "<leader>tc", function() M.container() end, { desc = "Terminal (container)" })

  -- ターミナルのバッファの中だけで使うキー
  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("devcontainer.terminal", {}),
    callback = function(ev)
      if vim.b[ev.buf].devcontainer_term == nil then return end
      local function bmap(mode, lhs, rhs, desc)
        map(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
      end
      bmap("t", "<C-/>", M.leave, "Back to editor")
      bmap("t", "<C-_>", M.leave, "which_key_ignore")
      bmap("t", "<Esc><Esc>", "<C-\\><C-n>", "Terminal normal mode")
      bmap("n", "]t", function() M.cycle(1) end, "Next terminal")
      bmap("n", "[t", function() M.cycle(-1) end, "Prev terminal")
      bmap("n", "q", M.hide, "Hide terminals")
    end,
  })
end

return M
