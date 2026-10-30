-- プロジェクトの検出と、プロジェクトごとの記憶（常に起動 / 使わない、前回起動時の設定ハッシュ）
local M = {}

local state_dir = vim.fn.stdpath("state") .. "/devcontainer"
local store_path = state_dir .. "/projects.json"

---@class devcontainer.Project
---@field root string .devcontainer のあるディレクトリ
---@field git_root string マウント元（git ルート。git 管理外なら root）
---@field status "idle"|"starting"|"ready"|"failed"|"stopped"
---@field mode? "container"|"host" C5 の答え（nil は未回答）
---@field asking? boolean C5 の確認を表示中
---@field container_id? string
---@field remote_user? string
---@field log string[]
---@field phase? string 起動中の進み具合
---@field agent_active? boolean エージェントのためにコンテナ全体の通信を制限している
---@field stopping? boolean コンテナを止めている、または作り直している途中
---@field node_modules_volume? boolean コンテナの node_modules にボリュームが重なっている（手元には無い）
---@field resolved? table<string, table<string, string>|"checking"> コンテナの node_modules で探したコマンド

---@type table<string, devcontainer.Project>
M.projects = {}

local function read_store()
  local f = io.open(store_path, "r")
  if not f then return {} end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and data or {}
end

local function write_store(data)
  vim.fn.mkdir(state_dir, "p")
  local f = assert(io.open(store_path, "w"))
  f:write(vim.json.encode(data))
  f:close()
end

---@param root string
function M.remembered(root)
  return read_store()[root] or {}
end

---@param root string
---@param fields table|nil nil なら記憶ごと消す
function M.remember(root, fields)
  local data = read_store()
  data[root] = fields and vim.tbl_extend("force", data[root] or {}, fields) or nil
  write_store(data)
end

local function has_config(dir)
  return vim.uv.fs_stat(dir .. "/.devcontainer/devcontainer.json") ~= nil
    or vim.uv.fs_stat(dir .. "/.devcontainer.json") ~= nil
end

--- path から上にたどって最初に見つかった devcontainer のルート
---@param path string
---@return string?
function M.find_root(path)
  if path == "" then return nil end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  for dir in vim.fs.parents(path .. "/_") do
    if has_config(dir) then return dir end
  end
end

---@param root string
---@return devcontainer.Project
function M.get(root)
  if not M.projects[root] then
    M.projects[root] = {
      root = root,
      git_root = vim.fs.root(root, ".git") or root,
      status = "idle",
      log = {},
    }
  end
  return M.projects[root]
end

--- バッファの devcontainer ルート（プロジェクト外なら nil）
---@param buf? integer
---@return string?
function M.root_for_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf or 0)
  -- oil:// などのスキームや無名バッファはカレントディレクトリで判断する
  if name == "" or name:match("^%a+://") then
    local oil_dir = name:match("^oil://(.*)")
    name = oil_dir or vim.fn.getcwd()
  end
  return M.find_root(name)
end

--- バッファが属するプロジェクト（未検出・管理外なら nil）
---@param buf? integer
---@return devcontainer.Project?
function M.for_buf(buf)
  local root = M.root_for_buf(buf)
  return root and M.projects[root] or nil
end

--- 読み込み済みのバッファのうち、プロジェクト配下のもの
---@param p devcontainer.Project
---@return integer[]
function M.bufs(p)
  return vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_loaded(b) and M.root_for_buf(b) == p.root
  end, vim.api.nvim_list_bufs())
end

--- .devcontainer 配下のファイル内容から作るハッシュ（設定変更の検知用）
---@param root string
function M.config_hash(root)
  local parts = {}
  local dir = root .. "/.devcontainer"
  if vim.uv.fs_stat(dir) then
    for name, type in vim.fs.dir(dir, { depth = 3 }) do
      -- .local は起動のたびに手元で書き出すもの（雛形の git の名前など）なので含めない
      if type == "file" and not vim.startswith(name, ".local/") then
        local f = io.open(dir .. "/" .. name, "r")
        if f then
          table.insert(parts, name .. "\0" .. f:read("*a"))
          f:close()
        end
      end
    end
  else
    local f = io.open(root .. "/.devcontainer.json", "r")
    if f then
      table.insert(parts, f:read("*a"))
      f:close()
    end
  end
  table.sort(parts)
  return vim.fn.sha256(table.concat(parts, "\0"))
end

M.state_dir = state_dir

return M
