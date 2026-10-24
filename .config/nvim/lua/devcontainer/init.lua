-- Dev Container 連携。要件は docs/devcontainer-nvim.md
local project = require("devcontainer.project")
local cli = require("devcontainer.cli")

local M = {}

--- 上書き用設定を書き出す直前に呼ばれるフック（後段のモジュールが runArgs などを足す）
---@type fun(config: table, p: devcontainer.Project)[]
M.override_hooks = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devcontainer" })
end

local function name(p)
  return vim.fs.basename(p.root)
end

---@type table<string, fun(p: devcontainer.Project)[]>
local waiters = {}

--- コンテナの準備ができたら fn を呼ぶ（準備済みなら即座に呼ぶ）
---@param p devcontainer.Project
---@param fn fun(p: devcontainer.Project)
function M.on_ready(p, fn)
  if p.status == "ready" then return fn(p) end
  waiters[p.root] = waiters[p.root] or {}
  table.insert(waiters[p.root], fn)
end

local function set_status(p, status)
  p.status = status
  if status ~= "starting" then p.phase = nil end
  vim.cmd.redrawstatus({ bang = true })
  if status == "ready" then
    for _, fn in ipairs(waiters[p.root] or {}) do fn(p) end
    waiters[p.root] = nil
    vim.api.nvim_exec_autocmds("User", { pattern = "DevcontainerReady", data = { root = p.root } })
  elseif status == "failed" or status == "stopped" then
    waiters[p.root] = nil
  end
end

---@param p devcontainer.Project
---@param opts? { rebuild?: boolean }
function M.start(p, opts)
  opts = opts or {}
  if p.status == "starting" then return end
  set_status(p, "starting")
  notify(("%s のコンテナを起動しています…"):format(name(p)))
  cli.up(p, opts, function(ok, err)
    if not ok and err == "mount_mismatch" then
      set_status(p, "failed")
      vim.ui.select({ "作り直す", "やめる" }, {
        prompt = ("%s の既存コンテナは手元と同じパスでマウントされていません"):format(name(p)),
      }, function(choice)
        if choice == "作り直す" then M.start(p, { rebuild = true }) end
      end)
      return
    end
    if not ok then
      set_status(p, "failed")
      notify(("%s の起動に失敗しました: %s"):format(name(p), err or ""), vim.log.levels.ERROR)
      M.show_log(p)
      return
    end
    project.remember(p.root, { config_hash = project.config_hash(p.root) })
    set_status(p, "ready")
    notify(("%s のコンテナが起動しました"):format(name(p)))
  end)
end

--- 前回起動時から設定が変わっていたら作り直すか確認してから起動する
---@param p devcontainer.Project
local function start_checked(p)
  local prev = project.remembered(p.root).config_hash
  if prev and prev ~= project.config_hash(p.root) then
    vim.ui.select({ "作り直す", "そのまま起動する" }, {
      prompt = ("%s の devcontainer 設定が変わっています"):format(name(p)),
    }, function(choice)
      if choice then M.start(p, { rebuild = choice == "作り直す" }) end
    end)
  else
    M.start(p)
  end
end

local asked = {}

--- 未対応のプロジェクトを見つけたときの確認（C5）
---@param root string
local function handle_root(root)
  if asked[root] then return end
  asked[root] = true
  local p = project.get(root)
  local choice = project.remembered(root).choice
  if choice == "always" then return start_checked(p) end
  if choice == "never" then return end

  local items = {
    { label = "起動する", run = function() start_checked(p) end },
    { label = "常に起動する", run = function()
      project.remember(root, { choice = "always" })
      start_checked(p)
    end },
    { label = "今回は使わない", run = function() end },
    { label = "このプロジェクトでは使わない", run = function()
      project.remember(root, { choice = "never" })
    end },
  }
  vim.ui.select(items, {
    prompt = ("%s に devcontainer.json が見つかりました"):format(name(p)),
    format_item = function(item) return item.label end,
  }, function(item)
    if item then item.run() end
  end)
end

local function detect(buf)
  local name_ = vim.api.nvim_buf_get_name(buf)
  local path = name_:match("^oil://(.*)") or (name_:match("^%a+://") and "" or name_)
  if path == "" then path = vim.fn.getcwd() end
  local root = project.find_root(path)
  if root then vim.schedule(function() handle_root(root) end) end
end

--- コマンドの対象プロジェクト（カレントバッファ → カレントディレクトリの順で探す）
local function current()
  local p = project.for_buf(0)
  if p then return p end
  local root = project.find_root(vim.fn.getcwd())
  if root then return project.get(root) end
  notify("devcontainer のプロジェクトではありません", vim.log.levels.WARN)
end

---@param p devcontainer.Project
function M.show_log(p)
  local buf = vim.fn.bufnr("devcontainer://log/" .. p.root)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "devcontainer://log/" .. p.root)
    vim.bo[buf].bufhidden = "hide"
  end
  local function refresh()
    if not vim.api.nvim_buf_is_valid(buf) then return true end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, p.log)
    vim.bo[buf].modifiable = false
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_win_set_cursor(win, { math.max(#p.log, 1), 0 })
    end
  end
  refresh()
  if vim.fn.bufwinid(buf) == -1 then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
  end
  if not vim.b[buf].devcontainer_log_attached then
    vim.b[buf].devcontainer_log_attached = true
    vim.api.nvim_create_autocmd("User", {
      pattern = "DevcontainerLog",
      callback = function(ev)
        if ev.data.root ~= p.root then return end
        return refresh()
      end,
    })
  end
end

--- ステータスライン用の表示（管理外なら空文字）
function M.status()
  local p = project.for_buf(0)
  if not p then return "" end
  local icons = { idle = "󰆧 ", starting = "󰑓 ", ready = " ", failed = " ", stopped = "󰆧 " }
  local text = icons[p.status] .. name(p)
  if p.status == "starting" and p.phase then text = text .. " · " .. p.phase end
  return text
end

function M.setup()
  if vim.fn.executable("devcontainer") == 0 then return end

  local group = vim.api.nvim_create_augroup("devcontainer", {})
  vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
    group = group,
    callback = function(ev) detect(ev.buf) end,
  })
  if vim.v.vim_did_enter == 1 then detect(vim.api.nvim_get_current_buf()) end

  local commands = {
    DevcontainerUp = function(p) M.start(p) end,
    DevcontainerRebuild = function(p) M.start(p, { rebuild = true }) end,
    DevcontainerStop = function(p)
      cli.stop(p, function(ok)
        if ok then
          set_status(p, "stopped")
          notify(("%s のコンテナを止めました"):format(name(p)))
        end
      end)
    end,
    DevcontainerLog = function(p) M.show_log(p) end,
    DevcontainerForget = function(p)
      project.remember(p.root, nil)
      asked[p.root] = nil
      notify(("%s の記憶を消しました"):format(name(p)))
    end,
  }
  for cmd, fn in pairs(commands) do
    vim.api.nvim_create_user_command(cmd, function()
      local p = current()
      if p then fn(p) end
    end, {})
  end
end

return M
