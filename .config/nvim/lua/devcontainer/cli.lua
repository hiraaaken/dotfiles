-- devcontainer CLI / docker の呼び出し
local project = require("devcontainer.project")

local M = {}

---@param p devcontainer.Project
---@param line string
local function append_log(p, line)
  table.insert(p.log, line)
  vim.api.nvim_exec_autocmds("User", { pattern = "DevcontainerLog", data = { root = p.root } })
end

--- 非同期でコマンドを実行し、stderr をログに流す。stdout は完了時に返す
---@param p devcontainer.Project
---@param cmd string[]
---@param on_line? fun(line: string) stderr の1行ごと
---@param on_exit fun(code: integer, stdout: string)
---@param timeout? integer ミリ秒。超えたら止めて code 124 を返す
local function run(p, cmd, on_line, on_exit, timeout)
  append_log(p, "$ " .. table.concat(cmd, " "))
  local partial = ""
  local ok, err = pcall(vim.system, cmd, {
    text = true,
    timeout = timeout,
    stderr = function(_, data)
      if not data then return end
      local lines = vim.split(partial .. data, "\n")
      partial = table.remove(lines)
      vim.schedule(function()
        for _, line in ipairs(lines) do
          if on_line then on_line(line) end
        end
      end)
    end,
  }, function(res)
    vim.schedule(function() on_exit(res.code, res.stdout or "") end)
  end)
  if not ok then
    append_log(p, tostring(err))
    on_exit(127, "")
  end
end

--- --log-format json の1行を読みやすくしてログに積み、段階が変わったら phase を更新する
local function handle_json_log(p, line)
  local ok, ev = pcall(vim.json.decode, line)
  if not ok or type(ev) ~= "table" then
    if line ~= "" then append_log(p, line) end
    return
  end
  if ev.type == "start" and ev.text then
    p.phase = ev.text:sub(1, 60)
  end
  if ev.text and ev.type ~= "stop" then
    for _, l in ipairs(vim.split(ev.text, "\n", { trimempty = true })) do
      append_log(p, l)
    end
  end
end

--- 元の devcontainer.json に、手元と同じ絶対パスでマウントする設定を足した上書き用設定を作る
---@param p devcontainer.Project
---@param cb fun(path?: string, err?: string)
function M.write_override(p, cb)
  run(p, { "devcontainer", "read-configuration", "--workspace-folder", p.root, "--log-format", "json" },
    function(line) handle_json_log(p, line) end,
    function(code, stdout)
      local ok, data = pcall(vim.json.decode, stdout)
      if code ~= 0 or not ok then return cb(nil, "read-configuration に失敗しました") end
      local config = data.configuration
      config.configFilePath = nil
      if config.dockerComposeFile then
        return cb(nil, "docker compose 構成のプロジェクトにはまだ対応していません")
      end
      config.workspaceMount = ("type=bind,source=%s,target=%s,consistency=cached"):format(p.git_root, p.git_root)
      config.workspaceFolder = p.root
      for _, hook in ipairs(require("devcontainer").override_hooks) do
        hook(config, p)
      end

      local dir = project.state_dir .. "/override/" .. vim.fn.sha256(p.root):sub(1, 16)
      vim.fn.mkdir(dir, "p")
      local path = dir .. "/devcontainer.json"
      local f = assert(io.open(path, "w"))
      f:write(vim.json.encode(config))
      f:close()
      cb(path)
    end)
end

---@param p devcontainer.Project
---@param opts { rebuild?: boolean }
---@param cb fun(ok: boolean, err?: string)
function M.up(p, opts, cb)
  M.write_override(p, function(override, err)
    if not override then return cb(false, err) end
    local cmd = {
      "devcontainer", "up",
      "--workspace-folder", p.root,
      "--override-config", override,
      "--log-format", "json",
    }
    if opts.rebuild then table.insert(cmd, "--remove-existing-container") end
    run(p, cmd, function(line) handle_json_log(p, line) end, function(code, stdout)
      local result
      for _, l in ipairs(vim.split(stdout, "\n", { trimempty = true })) do
        local ok, r = pcall(vim.json.decode, l)
        if ok and type(r) == "table" and r.outcome then result = r end
      end
      if code ~= 0 or not result or result.outcome ~= "success" then
        return cb(false, result and result.message or ("devcontainer up が失敗しました (exit " .. code .. ")"))
      end
      p.container_id = result.containerId
      p.remote_user = result.remoteUser
      -- 以前に別の設定で作られたコンテナが使い回されると、同じパスのマウントが無い
      M.has_same_path_mount(p, function(mounted)
        if mounted then return cb(true) end
        cb(false, "mount_mismatch")
      end)
    end)
  end)
end

---@param p devcontainer.Project
---@param cb fun(ok: boolean)
function M.stop(p, cb)
  if not p.container_id then return cb(false) end
  run(p, { "docker", "stop", p.container_id }, function(line) append_log(p, line) end, function(code)
    cb(code == 0)
  end)
end

---@param p devcontainer.Project
---@param cb fun(mounted: boolean)
function M.has_same_path_mount(p, cb)
  run(p, { "docker", "inspect", "--format", "{{json .Mounts}}", p.container_id }, nil, function(code, stdout)
    local ok, mounts = pcall(vim.json.decode, stdout)
    if code ~= 0 or not ok then return cb(false) end
    local want = {
      [p.git_root] = true,
      [require("devcontainer.tools").dir] = true,
      [require("devcontainer.tools").claude_dir] = true,
    }
    for _, m in ipairs(mounts) do
      want[m.Destination] = nil
    end
    cb(next(want) == nil)
  end)
end

M.append_log = append_log
M.run = run

return M
