-- コンテナ内の Claude Code（A1〜A4）と git の名前・メール（G2）
local project = require("devcontainer.project")
local tools = require("devcontainer.tools")
local cli = require("devcontainer.cli")

local M = {}

--- 全コンテナで共有するログイン（A2）。root だけが読み書きする
M.auth_dir = tools.claude_dir .. "/auth"
--- 以前の、設定ごと全コンテナで共有していた場所（ログインの移行元）
local legacy_dir = tools.claude_dir .. "/config"

--- 新しいプロジェクトの .claude.json に引き継ぐ項目（初回の画面を省くため）。
--- hooks や MCP サーバーなど、他のプロジェクトで実行されうるものは引き継がない
local account_keys = { "oauthAccount", "hasCompletedOnboarding", "lastOnboardingVersion", "userID", "theme" }

--- プロジェクトごとの Claude のディレクトリ。設定を共有すると、あるプロジェクトの依存パッケージが仕込んだ
--- hooks や MCP サーバーが他のプロジェクトでも動くので、共有するのはログインだけにする
---@param p devcontainer.Project
function M.project_dir(p)
  return ("%s/projects/%s"):format(tools.claude_dir, vim.fn.sha256(p.root):sub(1, 16))
end

---@param p devcontainer.Project
function M.config_dir(p)
  return M.project_dir(p) .. "/config"
end

--- ホストからコピーするもの（A3）。認証や履歴はコピーしない
local sync_items = { "settings.json", "CLAUDE.md", "skills", "agents" }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devcontainer" })
end

local function sh_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

--- 共有のログインとプロジェクトの設定の間で、新しい方の認証を取り込むスクリプト（root で実行する）。
--- プロジェクトで /login したりトークンが更新されたりしたら共有へ、他で更新されていたらプロジェクトへ。
--- コピー先は消してから書き、シンボリックリンクは読まない（root の cp で別のファイルを読み書きしないため）
---@param p devcontainer.Project
---@param user string プロジェクトの設定の持ち主
function M.sync_auth_script(p, user)
  local a, c, creds = M.auth_dir, M.config_dir(p), "/.credentials.json"
  local node = tools.prefix(p) .. "/node/bin/node"
  local pick = ([[const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); const o = {};
for (const k of %s) if (k in j) o[k] = j[k];
process.stdout.write(JSON.stringify(o))]]):format(vim.json.encode(account_keys))
  local function regular(path) return ("[ -f %s ] && [ ! -L %s ]"):format(path, path) end
  local function seed(from)
    return ("{ %s && %s %s %s > %s/account.json.tmp && mv %s/account.json.tmp %s/account.json || rm -f %s/account.json.tmp; }")
      :format(regular(from), node, "-e " .. sh_quote(pick), from, a, a, a, a)
  end
  return table.concat({
    ("mkdir -p %s %s && chown root:root %s && chmod 700 %s"):format(a, c, a, a),
    -- 以前の共有の場所からの移行
    ("[ -e %s%s ] || ! %s || { cp %s%s %s/ && touch -r %s%s %s%s; %s; }")
      :format(a, creds, regular(legacy_dir .. creds), legacy_dir, creds, a, legacy_dir, creds, a, creds,
        seed(legacy_dir .. "/.claude.json")),
    ("if %s && { [ ! -e %s%s ] || [ %s%s -nt %s%s ]; }; then"):format(regular(c .. creds), a, creds, c, creds, a, creds),
    ("  rm -f %s%s && cp %s%s %s/ && touch -r %s%s %s%s && chmod 600 %s%s"):format(a, creds, c, creds, a, c, creds, a, creds, a, creds),
    ("  %s"):format(seed(c .. "/.claude.json")),
    ("elif [ -f %s%s ] && { [ ! -e %s%s ] || [ %s%s -nt %s%s ]; }; then"):format(a, creds, c, creds, a, creds, c, creds),
    ("  rm -f %s%s && cp -p %s%s %s/"):format(c, creds, a, creds, c),
    "fi",
    ("[ -e %s/.claude.json ] || [ ! -f %s/account.json ] || cp %s/account.json %s/.claude.json"):format(c, a, a, c),
    ("chown -R %s %s"):format(user, c),
  }, "\n")
end

--- ホストの ~/.claude から設定をボリュームへコピーする。シンボリックリンクは実体をコピーする
---@param p devcontainer.Project
---@param dir string コピー先
---@param owner string
---@param cb fun(ok: boolean)
function M.copy_settings(p, dir, owner, cb)
  local home = vim.fn.expand("~/.claude")
  local items = vim.tbl_filter(function(i) return vim.uv.fs_stat(home .. "/" .. i) ~= nil end, sync_items)
  local clear = ("mkdir -p %s && cd %s && rm -rf %s"):format(dir, dir, table.concat(sync_items, " "))
  local extract = ("%s && tar -xf - && chown -R %s %s"):format(clear, owner, dir)
  local script = ("COPYFILE_DISABLE=1 tar -chf - -C %s %s | docker exec -i -u root %s sh -c %s"):format(
    sh_quote(home),
    table.concat(vim.tbl_map(sh_quote, items), " "),
    p.container_id,
    sh_quote(extract)
  )
  if #items == 0 then script = ("docker exec -u root %s sh -c %s"):format(p.container_id, sh_quote(clear)) end
  cli.run(p, { "sh", "-c", script }, function(line) cli.append_log(p, line) end, function(code) cb(code == 0) end)
end

--- git の名前とメールだけをホストからコピーする（G2）。手元と所有者が違って見えても使えるようにする
---@param p devcontainer.Project
---@param user string
---@param cb fun()
function M.copy_git_identity(p, user, cb)
  local function host_config(key)
    local out = vim.system({ "git", "-C", p.root, "config", key }, { text = true }):wait()
    return out.code == 0 and vim.trim(out.stdout) or nil
  end
  local lines = { "command -v git >/dev/null || exit 0" }
  for _, key in ipairs({ "user.name", "user.email" }) do
    local value = host_config(key)
    if value then table.insert(lines, ("git config --global %s %s"):format(key, sh_quote(value))) end
  end
  tools.exec(p, "root", {
    "sh", "-c",
    "command -v git >/dev/null || exit 0; git config --system --get-all safe.directory | grep -qx '*' || git config --system --add safe.directory '*'",
  }, function()
    tools.exec(p, user, { "sh", "-c", table.concat(lines, "\n") }, function() cb() end)
  end)
end

--- コンテナを作ってから初めて準備ができたときに、Claude の設定と git の名前・メールをコピーする
---@param p devcontainer.Project
---@param cb fun()
function M.on_container_created(p, cb)
  -- コピー先も記録する（場所を変えたら、既存のコンテナでもコピーし直す）
  local synced = p.container_id .. ":" .. M.config_dir(p)
  if project.remembered(p.root).synced_container == synced then return cb() end
  local user = p.remote_user or "root"
  M.copy_settings(p, M.config_dir(p), user, function(ok)
    if not ok then cli.append_log(p, "Claude の設定のコピーに失敗しました") end
    M.copy_git_identity(p, user, function()
      project.remember(p.root, { synced_container = synced })
      cb()
    end)
  end)
end

---@param p devcontainer.Project
function M.sync(p)
  M.copy_settings(p, M.config_dir(p), p.remote_user or "root", function(ok)
    if ok then
      notify("Claude の設定をコンテナに同期しました")
    else
      notify("Claude の設定の同期に失敗しました（:DevcontainerLog）", vim.log.levels.ERROR)
    end
  end)
end

--- コンテナ内で Claude を開く。ログインは全コンテナで共有するので、開くたびに新しい方を取り込む（A2）
---@param p devcontainer.Project
---@param args? string[]
function M.open(p, args)
  local user = p.remote_user or "root"
  local cmd = {
    "docker", "exec", "-it", "-w", p.root, "-u", user,
    "-e", "CLAUDE_CONFIG_DIR=" .. M.config_dir(p),
    -- ボリュームは読み取り専用なので自分では更新できない
    "-e", "DISABLE_AUTOUPDATER=1",
    p.container_id, tools.prefix(p) .. "/npm/bin/claude",
  }
  vim.list_extend(cmd, args or {})
  -- エージェント用（agent.lua）の認証は取り込まない（エージェントが別のアカウントにすり替えられるため）
  local script = M.sync_auth_script(p, user)
  tools.exec(p, "root", { "sh", "-c", script }, function()
    -- --resume などの引数ごとに一つ。開いていればそれを表示する
    local key = ("claude:%s:%s"):format(p.root, table.concat(args or {}, " "))
    require("devcontainer.terminal").open({ cmd = cmd, cwd = p.root, name = "claude", key = key, root = p.root })
  end)
end

--- devcontainer プロジェクト（コンテナを使う、または未回答）のバッファか
function M.in_container_project()
  if not require("devcontainer").enabled then return nil end
  local root = project.root_for_buf(0) or project.find_root(vim.fn.getcwd())
  if not root then return nil end
  local p = project.get(root)
  if p.mode == "host" then return nil end
  return p
end

--- コンテナ内の Claude を開く（準備中なら待つ）
---@param args? string[]
function M.open_current(args)
  local p = M.in_container_project()
  if not p then return notify("devcontainer のプロジェクトではありません", vim.log.levels.WARN) end
  require("devcontainer").when_ready(p, function() M.open(p, args) end)
end

--- ホストの Claude を起動する claudecode.nvim のコマンド
--- （Send / Add / TreeAdd も、Claude が未接続なら起動する）
local launch_commands = {
  "ClaudeCode", "ClaudeCodeOpen", "ClaudeCodeFocus", "ClaudeCodeSelectModel",
  "ClaudeCodeSend", "ClaudeCodeAdd", "ClaudeCodeTreeAdd",
}

--- devcontainer プロジェクトではホストの Claude（claudecode.nvim）を起動させない（A4）
--- claudecode.nvim の setup 後に呼ぶ
function M.guard_host_commands()
  local commands = vim.api.nvim_get_commands({})
  for _, name in ipairs(launch_commands) do
    local def = commands[name]
    if def and def.callback then
      local callback = def.callback
      vim.api.nvim_create_user_command(name, function(args)
        if M.in_container_project() then
          return notify("devcontainer のプロジェクトでは、ホストの Claude は使えません（<leader>ac でコンテナの Claude を開く）", vim.log.levels.WARN)
        end
        callback(args)
      end, {
        -- nvim_get_commands は "0" / "1" を文字列で返すが、作るときは数値でないと受け付けない
        nargs = tonumber(def.nargs) or def.nargs,
        bang = def.bang,
        range = def.range and (def.range == "." or tonumber(def.range) or def.range),
        complete = def.complete ~= "" and def.complete or nil,
        desc = def.definition,
        force = true,
      })
    end
  end
end

return M
