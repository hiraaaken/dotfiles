-- エージェントに任せるモード（A5）
-- sudo を使えない専用ユーザーで Claude を動かし、そのユーザーの通信だけを許可リストの宛先に制限する。
-- iptables はコンテナのネットワークを共有するヘルパーコンテナから root で設定するので、
-- プロジェクトのイメージに iptables が無くてもよく、コンテナ内の誰もルールを変えられない
local tools = require("devcontainer.tools")
local claude = require("devcontainer.claude")
local cli = require("devcontainer.cli")

local M = {}

M.user = "nvim-agent"
M.config_dir = tools.claude_dir .. "/agent"

local firewall_image = "nvim-devcontainer-firewall"

--- 許可する宛先の既定値。vim.g.devcontainer_agent_allowlist で足せる
M.allowlist = {
  "api.anthropic.com",
  "console.anthropic.com",
  "platform.claude.com",
  "claude.ai",
  "statsig.anthropic.com",
  "statsig.com",
  "sentry.io",
}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devcontainer" })
end

--- 専用ユーザーを作り、sudo できないことを確かめる
---@param p devcontainer.Project
---@param cb fun(uid?: string, err?: string)
local function ensure_user(p, cb)
  local u = M.user
  local script = ("id -u %s >/dev/null 2>&1 || useradd -m -s /bin/sh %s 2>/dev/null || adduser -D -s /bin/sh %s; id -u %s")
    :format(u, u, u, u)
  tools.exec(p, "root", { "sh", "-c", script }, function(code, out)
    local uid = vim.trim(out):match("(%d+)$")
    if code ~= 0 or not uid then return cb(nil, "専用ユーザーを作れませんでした") end
    tools.exec(p, u, { "sh", "-c", "command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1 && echo sudo" },
      function(_, sudo)
        if vim.trim(sudo) == "sudo" then return cb(nil, M.user .. " が sudo を使えるため中止しました") end
        cb(uid)
      end)
  end)
end

---@param p devcontainer.Project
---@param cb fun(ok: boolean)
local function ensure_firewall_image(p, cb)
  cli.run(p, { "docker", "image", "inspect", firewall_image }, nil, function(code)
    if code == 0 then return cb(true) end
    local dockerfile = [[FROM alpine:3.20\nRUN apk add --no-cache iptables ip6tables bind-tools\n]]
    cli.run(p, { "sh", "-c", ("printf '%s' | docker build -t %s - 1>&2"):format(dockerfile, firewall_image) },
      function(line) cli.append_log(p, line) end,
      function(bcode) cb(bcode == 0) end)
  end)
end

--- 専用ユーザーの通信を、ループバック・DNS・許可リストの宛先だけに制限する。起動のたびに引き直す
---@param p devcontainer.Project
---@param uid string
---@param cb fun(ok: boolean)
local function apply_firewall(p, uid, cb)
  local hosts = vim.list_extend(vim.deepcopy(M.allowlist), vim.g.devcontainer_agent_allowlist or {})
  local script = [[
set -eu
uid=$1; shift
for t in iptables ip6tables; do
  $t -L OUTPUT >/dev/null 2>&1 || continue
  $t -N NVIM_AGENT 2>/dev/null || $t -F NVIM_AGENT
  $t -C OUTPUT -m owner --uid-owner "$uid" -j NVIM_AGENT 2>/dev/null \
    || $t -I OUTPUT 1 -m owner --uid-owner "$uid" -j NVIM_AGENT
  $t -A NVIM_AGENT -o lo -j ACCEPT
  $t -A NVIM_AGENT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  $t -A NVIM_AGENT -p udp --dport 53 -j ACCEPT
  $t -A NVIM_AGENT -p tcp --dport 53 -j ACCEPT
done
for host in "$@"; do
  for ip in $(dig +short A "$host" | grep -E '^[0-9.]+$' | sort -u); do
    iptables -A NVIM_AGENT -d "$ip" -j ACCEPT
    echo "allow $host $ip" >&2
  done
done
iptables -A NVIM_AGENT -j REJECT
ip6tables -L OUTPUT >/dev/null 2>&1 && ip6tables -A NVIM_AGENT -j REJECT || true
]]
  local cmd = {
    "docker", "run", "--rm",
    "--network", "container:" .. p.container_id,
    "--cap-add", "NET_ADMIN",
    firewall_image, "sh", "-c", script, "sh", uid,
  }
  cli.run(p, vim.list_extend(cmd, hosts), function(line) cli.append_log(p, line) end, function(code) cb(code == 0) end)
end

--- 普段の Claude の認証と設定を専用ユーザー用にコピーする（ログインは共有する）
---@param p devcontainer.Project
---@param cb fun(ok: boolean, err?: string)
local function prepare_config(p, cb)
  local src, dst = claude.config_dir, M.config_dir
  local script = table.concat({
    ("[ -f %s/.credentials.json ] || exit 3"):format(src),
    ("mkdir -p %s"):format(dst),
    ("for i in settings.json CLAUDE.md skills agents; do rm -rf %s/$i; [ ! -e %s/$i ] || cp -a %s/$i %s/; done")
      :format(dst, src, src, dst),
    -- トークンは更新されるので新しい方を使う
    ("[ %s/.credentials.json -nt %s/.credentials.json ] || cp -p %s/.credentials.json %s/")
      :format(dst, src, src, dst),
    ("[ -f %s/.claude.json ] || [ ! -f %s/.claude.json ] || cp %s/.claude.json %s/"):format(dst, src, src, dst),
    ("chown -R %s %s && chmod 700 %s"):format(M.user, dst, dst),
  }, "\n")
  tools.exec(p, "root", { "sh", "-c", script }, function(code)
    if code == 3 then return cb(false, "先にコンテナの Claude（<leader>ac）でログインしてください") end
    cb(code == 0, "Claude の設定を用意できませんでした")
  end)
end

---@param p devcontainer.Project
function M.open(p)
  if not p.tools_ok then
    return notify("ボリュームの Claude Code が使えません（:DevcontainerLog）", vim.log.levels.ERROR)
  end
  local function fail(msg)
    notify(msg .. "（:DevcontainerLog）", vim.log.levels.ERROR)
  end
  notify("エージェント用の環境を準備しています…")
  ensure_user(p, function(uid, err)
    if not uid then return fail(err) end
    ensure_firewall_image(p, function(ok)
      if not ok then return fail("ファイアウォール用のイメージを作れませんでした") end
      apply_firewall(p, uid, function(fw_ok)
        -- 制限をかけられなければ起動しない
        if not fw_ok then return fail("通信の制限を設定できませんでした") end
        prepare_config(p, function(cfg_ok, cfg_err)
          if not cfg_ok then return fail(cfg_err) end
          claude.copy_git_identity(p, M.user, function()
            Snacks.terminal.toggle({
              "docker", "exec", "-it", "-w", p.root, "-u", M.user,
              "-e", "CLAUDE_CONFIG_DIR=" .. M.config_dir,
              "-e", "DISABLE_AUTOUPDATER=1",
              p.container_id, tools.prefix(p) .. "/npm/bin/claude", "--dangerously-skip-permissions",
            }, { cwd = p.root })
          end)
        end)
      end)
    end)
  end)
end

return M
