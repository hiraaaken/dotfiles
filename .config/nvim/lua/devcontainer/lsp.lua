-- LSP をコンテナ内で動かす（L1〜L6）
-- vim.lsp.start を包み、devcontainer プロジェクト配下のバッファでは docker exec 経由の cmd に差し替える
local project = require("devcontainer.project")
local tools = require("devcontainer.tools")

local M = {}

--- 手元で動かす LSP（L2）
local host_only = { copilot = true }

--- LSP 本体のほかにコンテナに必要なコマンド（L6）
local requires = {
  elmls = { "elm" },
}

--- nvim-lspconfig で cmd が関数になっている LSP の、コンテナでの cmd
--- （関数版と同じく、プロジェクトの node_modules/.bin にあればそちらを使う）
local function_cmds = {
  ts_ls = { "typescript-language-server", "--stdio" },
  tailwindcss = { "tailwindcss-language-server", "--stdio" },
  html = { "vscode-html-language-server", "--stdio" },
  cssls = { "vscode-css-language-server", "--stdio" },
  svelte = { "svelteserver", "--stdio" },
  eslint = { "vscode-eslint-language-server", "--stdio" },
  oxfmt = { "oxfmt", "--lsp" },
}

--- プロジェクトの node_modules にあるコマンド。Vite+ は oxfmt などを依存として持つが、
--- pnpm だと node_modules/.bin に置かれないので、vite-plus の実体の隣も探す
---@param root string
---@param name string
---@return string?
local function project_bin(root, name)
  local bin = vim.fs.joinpath(root, "node_modules/.bin", name)
  if vim.uv.fs_stat(bin) then return bin end
  local vite_plus = vim.uv.fs_realpath(vim.fs.joinpath(root, "node_modules/vite-plus"))
  if not vite_plus then return end
  bin = vim.fs.joinpath(vim.fs.dirname(vite_plus), name, "bin", name)
  if vim.uv.fs_stat(bin) then return bin end
end
M.project_bin = project_bin

---@type table<integer, string> client id → プロジェクトのルート
local clients = {}

local warned = {}

local function warn_once(key, msg)
  if warned[key] then return end
  warned[key] = true
  vim.notify(msg, vim.log.levels.WARN, { title = "devcontainer" })
end

--- プロジェクト配下の読み込み済みバッファで、LSP の起動をやり直す
---@param p devcontainer.Project
function M.retrigger(p)
  for _, b in ipairs(project.bufs(p)) do
    if vim.bo[b].filetype ~= "" then
      pcall(vim.api.nvim_exec_autocmds, "FileType", { group = "nvim.lsp.enable", buffer = b, modeline = false })
    end
  end
end

--- プロジェクトの LSP を正常に終了させる。cb は終わったら（最大 3 秒待って）呼ぶ
---@param p devcontainer.Project
---@param cb? fun()
function M.stop(p, cb)
  local stopping = {}
  for id, root in pairs(clients) do
    if root == p.root then
      -- 終了するまでは表に残し、手元のクライアントとして使い回されないようにする
      local client = vim.lsp.get_client_by_id(id)
      if client then
        client:stop()
        table.insert(stopping, client)
      else
        clients[id] = nil
      end
    end
  end
  if not cb then return end
  local deadline = vim.uv.now() + 3000
  local function check()
    -- is_stopped() は停止を頼んだ直後から true になるので、プロセスが終わってクライアントが消えるのを待つ
    local done = vim.iter(stopping):all(function(c) return vim.lsp.get_client_by_id(c.id) == nil end)
    if done or vim.uv.now() > deadline then return cb() end
    vim.defer_fn(check, 100)
  end
  check()
end

--- コンテナ内にコマンドがあるか（結果はプロジェクトごとに覚える。未確認なら確認を始めて nil）
---@param p devcontainer.Project
---@param names string[]
---@return boolean?
local function available(p, names)
  p.commands = p.commands or {}
  local missing, pending = {}, false
  for _, n in ipairs(names) do
    if p.commands[n] == nil then
      pending = true
      p.commands[n] = "checking"
      tools.exec(p, p.remote_user or "root",
        { "sh", "-c", ('PATH="%s:$PATH" command -v %s'):format(tools.path(p), n) },
        function(code)
          p.commands[n] = code == 0
          M.retrigger(p)
        end)
    elseif p.commands[n] == "checking" then
      pending = true
    elseif not p.commands[n] then
      table.insert(missing, n)
    end
  end
  if #missing > 0 then return false, missing end
  if pending then return nil end
  return true
end

--- 文字列の中の手元の mason のパスを、ボリュームの npm のパスに置き換える
---@param p devcontainer.Project
local function rewrite_paths(p, value)
  local mason = vim.fn.stdpath("data") .. "/mason/packages/"
  if type(value) == "string" then
    local rest = vim.startswith(value, mason) and value:sub(#mason + 1):match("^[^/]+/node_modules/(.*)$")
    return rest and ("%s/npm/lib/node_modules/%s"):format(tools.prefix(p), rest) or value
  elseif type(value) == "table" then
    local out = {}
    for k, v in pairs(value) do out[k] = rewrite_paths(p, v) end
    return setmetatable(out, getmetatable(value))
  end
  return value
end

---@param p devcontainer.Project
---@param config vim.lsp.ClientConfig
---@return vim.lsp.ClientConfig?
local function to_container(p, config)
  local host_cmd = config.cmd
  if type(host_cmd) ~= "table" then
    host_cmd = function_cmds[config.name] and vim.deepcopy(function_cmds[config.name])
    if not host_cmd then
      warn_once(p.root .. config.name, ("%s は cmd が関数のため、コンテナでは起動しません"):format(config.name))
      return
    end
    host_cmd[1] = project_bin(config.root_dir or p.root, host_cmd[1]) or host_cmd[1]
  end
  local bin = host_cmd[1]:sub(1, 1) == "/" and vim.startswith(host_cmd[1], p.git_root) and host_cmd[1]
    or vim.fs.basename(host_cmd[1])
  local ok, missing = available(p, vim.list_extend({ bin }, requires[config.name] or {}))
  if ok == nil then return end
  if not ok then
    warn_once(p.root .. config.name, ("%s: コンテナに %s が無いため起動しません"):format(config.name, table.concat(missing, ", ")))
    return
  end

  config = vim.deepcopy(config)
  local cwd = config.root_dir and vim.startswith(config.root_dir, p.git_root) and config.root_dir or p.root
  local cmd = { "docker", "exec", "-i", "-w", cwd, "-u", p.remote_user or "root" }
  for k, v in pairs(config.cmd_env or {}) do
    vim.list_extend(cmd, { "-e", ("%s=%s"):format(k, v) })
  end
  vim.list_extend(cmd, { p.container_id, "sh", "-c", ('PATH="%s:$PATH" exec "$@"'):format(tools.path(p)), "sh", bin })
  config.cmd = vim.list_extend(cmd, host_cmd, 2)
  config.cmd_env = nil
  config.init_options = rewrite_paths(p, config.init_options)
  config.settings = rewrite_paths(p, config.settings)

  -- プロジェクトの TypeScript があればそちらを、無ければボリュームのものを使う（L5）
  local tsserver = (config.root_dir or p.root) .. "/node_modules/typescript/lib"
  if not vim.uv.fs_stat(tsserver) then tsserver = tools.prefix(p) .. "/npm/lib/node_modules/typescript/lib" end
  if config.name == "ts_ls" then
    config.init_options = config.init_options or {}
    config.init_options.tsserver = vim.tbl_extend("force", config.init_options.tsserver or {}, { path = tsserver })
  end

  -- 手元の nvim の PID はコンテナから見えず、親プロセス監視で LSP が終了してしまう
  local before_init = config.before_init
  config.before_init = function(params, c)
    params.processId = vim.NIL
    if before_init then before_init(params, c) end
  end
  return config
end

--- 既定の使い回しの判定（vim.lsp.start の既定に合わせ、名前と root が同じなら使い回す）
---@param client vim.lsp.Client
---@param config vim.lsp.ClientConfig
local function same_root(client, config)
  return client.name == config.name and not client:is_stopped() and client.root_dir == config.root_dir
end

--- 持ち主（コンテナのプロジェクトのルート、手元なら nil）が同じクライアントだけを使い回す。
--- 既定の判定は名前と root しか見ないので、同じ root の手元とコンテナのクライアントが混ざる
---@param opts vim.lsp.start.Opts
---@param owner? string
local function with_owner(opts, owner)
  local inner = opts.reuse_client or same_root
  return vim.tbl_extend("force", opts, {
    reuse_client = function(client, config)
      return clients[client.id] == owner and inner(client, config)
    end,
  })
end

function M.setup()
  local start = vim.lsp.start
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.start = function(config, opts)
    opts = opts or {}
    if host_only[config.name] then return start(config, opts) end
    local bufnr = opts.bufnr and opts.bufnr ~= 0 and opts.bufnr or vim.api.nvim_get_current_buf()
    local root = project.root_for_buf(bufnr)
    if not root then return start(config, with_owner(opts, nil)) end

    -- 起動するか未回答、またはコンテナの準備ができるまでは何も起動しない（L3, C9）
    local p = project.get(root)
    if p.mode == "host" then return start(config, with_owner(opts, nil)) end
    if p.mode ~= "container" or p.status ~= "ready" then return end

    -- root_markers の設定は vim.lsp.start の中で root を決めるので、cwd や node_modules を探す前に同じく決めておく
    if not config.root_dir and opts._root_markers then
      config = vim.deepcopy(config)
      config.root_dir = vim.fs.root(bufnr, opts._root_markers)
    end
    local c = to_container(p, config)
    if not c then return end
    local id = start(c, with_owner(opts, p.root))
    if id then clients[id] = p.root end
    return id
  end
end

return M
