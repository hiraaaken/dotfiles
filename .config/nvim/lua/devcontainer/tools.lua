-- コンテナ間で共有する名前付きボリューム（L4, A1）
-- - ツール: LSP 本体・専用 Node・Claude Code。手元の mason と同じ npm パッケージを、
--   ヘルパーコンテナから入れる。プロジェクトのコンテナには読み取り専用でマウントする
-- - Claude: 認証と設定（A2, A3）
local cli = require("devcontainer.cli")

local M = {}

M.volume = "nvim-devcontainer-tools"
M.dir = "/opt/nvim-dc"
M.claude_volume = "nvim-devcontainer-claude"
M.claude_dir = "/opt/nvim-dc-claude"

local helper_images = { glibc = "node:22-slim", musl = "node:22-alpine" }

--- 上書き設定にボリュームのマウントを足す（C4 の override_hooks から呼ばれる）
---@param config table
function M.add_mounts(config)
  config.mounts = config.mounts or {}
  table.insert(config.mounts, ("source=%s,target=%s,type=volume,readonly"):format(M.volume, M.dir))
  table.insert(config.mounts, ("source=%s,target=%s,type=volume"):format(M.claude_volume, M.claude_dir))
end

--- 手元の mason に入っている npm パッケージ（バージョン込み）
---@return string[]
local function npm_packages()
  -- typescript-language-server は tsserver.js を使うので、tsserver の無い TypeScript 7 以降は避ける
  local pkgs = { "typescript@5", "@anthropic-ai/claude-code" }
  local dir = vim.fn.stdpath("data") .. "/mason/packages"
  for name in vim.fs.dir(dir) do
    local f = io.open(dir .. "/" .. name .. "/mason-receipt.json", "r")
    if f then
      local ok, receipt = pcall(vim.json.decode, f:read("*a"))
      f:close()
      local id = ok and receipt.source and receipt.source.id or ""
      local spec = id:match("^pkg:npm/(.+)$")
      if spec then
        spec = spec:gsub("%%40", "@")
        if not vim.tbl_contains(pkgs, spec) then table.insert(pkgs, spec) end
      end
    end
  end
  table.sort(pkgs)
  return pkgs
end

--- ボリューム内で使う、libc ごとのツールのディレクトリ
---@param p devcontainer.Project
function M.prefix(p)
  return ("%s/%s"):format(M.dir, p.libc or "glibc")
end

--- LSP を動かすときの PATH の前置き（専用 Node と npm の bin）
---@param p devcontainer.Project
function M.path(p)
  local t = M.prefix(p)
  return ("%s/node/bin:%s/npm/bin"):format(t, t)
end

---@param p devcontainer.Project
---@param user string
---@param cmd string[]
---@param cb fun(code: integer, stdout: string)
local function exec(p, user, cmd, cb)
  cli.run(p, vim.list_extend({ "docker", "exec", "-u", user, p.container_id }, cmd), nil, cb)
end
M.exec = exec

--- ヘルパーコンテナでボリュームにツールを入れる
---@param p devcontainer.Project
---@param pkgs string[]
---@param stamp string
---@param cb fun(ok: boolean)
local function install(p, pkgs, stamp, cb)
  local d = M.prefix(p)
  local script = table.concat({
    "set -eu",
    ("rm -rf %s.tmp && mkdir -p %s.tmp/node/bin"):format(d, d),
    ("cp /usr/local/bin/node %s.tmp/node/bin/"):format(d),
    ('npm install -g --no-fund --no-audit --prefix %s.tmp/npm "$@" 1>&2'):format(d),
    ("rm -rf %s && mv %s.tmp %s"):format(d, d, d),
    ("echo %s > %s/.stamp"):format(stamp, d),
  }, "\n")
  -- 名前を固定して、同時に二つ入れないようにする。時間切れのときはこの名前で消す
  local name = "nvim-devcontainer-install-" .. p.libc
  local cmd = {
    "docker", "run", "--rm", "--name", name,
    "-v", M.volume .. ":" .. M.dir,
    helper_images[p.libc],
    "sh", "-c", script, "sh",
  }
  vim.list_extend(cmd, pkgs)
  cli.run(p, cmd, function(line) cli.append_log(p, line) end, function(code)
    if code == 124 then
      cli.append_log(p, "ツールのインストールが時間切れになりました")
      vim.system({ "docker", "rm", "-f", name })
    end
    cb(code == 0)
  end, 15 * 60 * 1000)
end

--- コンテナの libc を調べ、ボリュームのツールが古ければ入れ直し、動くか確かめる
--- 失敗しても起動は止めない（npm の LSP と Claude が使えないだけ）
---@param p devcontainer.Project
---@param cb fun()
function M.prepare(p, cb)
  p.phase = "ツールを確認中"
  p.tools_ok = false
  exec(p, "root", { "sh", "-c", "ls /lib/ld-musl-* >/dev/null 2>&1 && echo musl || echo glibc" }, function(code, out)
    p.libc = code == 0 and vim.trim(out) or "glibc"
    local pkgs = npm_packages()
    local stamp = vim.fn.sha256(table.concat(pkgs, " ")):sub(1, 16)
    local function verify()
      exec(p, p.remote_user or "root",
        { "sh", "-c", ("%s/node/bin/node --version && %s/npm/bin/claude --version"):format(M.prefix(p), M.prefix(p)) },
        function(vcode)
          p.tools_ok = vcode == 0
          if not p.tools_ok then
            cli.append_log(p, "ボリュームの Node / Claude Code がこのコンテナでは動きません")
          end
          cb()
        end)
    end
    exec(p, "root", { "cat", M.prefix(p) .. "/.stamp" }, function(scode, current)
      if scode == 0 and vim.trim(current) == stamp then return verify() end
      p.phase = "LSP と Claude Code をボリュームに入れています"
      vim.cmd.redrawstatus({ bang = true })
      install(p, pkgs, stamp, function(ok)
        if not ok then
          cli.append_log(p, "ツールのインストールに失敗しました")
          return cb()
        end
        verify()
      end)
    end)
  end)
end

return M
