-- エージェントに任せるモード（A5）
-- sudo を使えない専用ユーザーで Claude を動かし、そのユーザーの通信だけを許可リストの宛先に制限する。
-- iptables はコンテナのネットワークを共有するヘルパーコンテナから root で設定するので、
-- プロジェクトのイメージに iptables が無くてもよく、コンテナ内の誰もルールを変えられない
local tools = require("devcontainer.tools")
local claude = require("devcontainer.claude")
local cli = require("devcontainer.cli")

local M = {}

M.user = "nvim-agent"
--- 専用ユーザーの Claude のディレクトリ（プロジェクトごと）
---@param p devcontainer.Project
function M.config_dir(p)
  return claude.project_dir(p) .. "/agent"
end

local firewall_image = "nvim-devcontainer-firewall"

--- 許可する宛先の既定値。vim.g.devcontainer_agent_allowlist で足せる
--- 誰でも送れる宛先（statsig.com や sentry.io）は持ち出しに使えるので入れず、
--- テレメトリとエラー報告は CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC で止める
M.allowlist = {
  "api.anthropic.com",
  "console.anthropic.com",
  "platform.claude.com",
  "claude.ai",
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

--- コンテナのネットワークを共有するヘルパーコンテナで、root としてスクリプトを実行する
---@param p devcontainer.Project
---@param script string
---@param args string[]
---@param cb fun(ok: boolean)
local function run_firewall(p, script, args, cb)
  local cmd = {
    "docker", "run", "--rm",
    "--network", "container:" .. p.container_id,
    "--cap-add", "NET_ADMIN",
    firewall_image, "sh", "-c", script, "sh",
  }
  cli.run(p, vim.list_extend(cmd, args), function(line) cli.append_log(p, line) end, function(code) cb(code == 0) end)
end

--- 出ていく通信へのルールから NVIM_AGENT に飛ぶものを消す（$t は iptables か ip6tables）
local unjump = [[
unjump() {
  $t -S OUTPUT | grep -e '-j NVIM_AGENT$' | sed 's/^-A /-D /' | while read -r rule; do $t $rule; done
}
]]

--- コンテナ全体の通信を、ループバック・DNS サーバー・許可リストの宛先だけに制限する。
--- uid ごとに制限すると、エージェントが書いたファイルを普段のユーザーが実行して抜けられるので、
--- エージェントが動いている間は uid を問わず制限する。起動のたびに引き直す
---@param p devcontainer.Project
---@param cb fun(ok: boolean)
local function apply_firewall(p, cb)
  local hosts = vim.list_extend(vim.deepcopy(M.allowlist), vim.g.devcontainer_agent_allowlist or {})
  local script = unjump .. [[
set -eu
# ルールを変える前に引く（引き直しの途中で制限が外れないよう、チェーンは iptables-restore で一度に入れ替える）
v4=""
for host in "$@"; do
  for ip in $(dig +short A "$host" | grep -E '^[0-9.]+$'); do
    v4="$v4 $ip"
    echo "allow $host $ip" >&2
  done
done
[ -n "$v4" ] || { echo "許可リストの宛先を引けませんでした" >&2; exit 1; }
ns=$(awk '/^nameserver/ { print $2 }' /etc/resolv.conf)
for t in iptables ip6tables; do
  $t -L OUTPUT >/dev/null 2>&1 || continue
  {
    echo '*filter'
    echo ':NVIM_AGENT - [0:0]'
    echo '-A NVIM_AGENT -o lo -j ACCEPT'
    echo '-A NVIM_AGENT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
    # DNS はコンテナの DNS サーバー宛てだけ（宛先を問わず 53 番を開けると、そこから持ち出せる）
    for n in $ns; do
      case $n in *:*) [ $t = ip6tables ] || continue ;; *) [ $t = iptables ] || continue ;; esac
      echo "-A NVIM_AGENT -d $n -p udp --dport 53 -j ACCEPT"
      echo "-A NVIM_AGENT -d $n -p tcp --dport 53 -j ACCEPT"
    done
    if [ $t = iptables ]; then
      for ip in $(printf '%s\n' $v4 | sort -u); do echo "-A NVIM_AGENT -d $ip -j ACCEPT"; done
    fi
    echo '-A NVIM_AGENT -j REJECT'
    echo 'COMMIT'
  } | $t-restore --noflush
  # 以前の uid ごとの制限が残っていれば外し、全体に掛ける
  $t -S OUTPUT | grep -q -x -e '-A OUTPUT -j NVIM_AGENT' || $t -I OUTPUT 1 -j NVIM_AGENT
  $t -S OUTPUT | grep -e '-j NVIM_AGENT$' | grep -v -x -e '-A OUTPUT -j NVIM_AGENT' | sed 's/^-A /-D /' \
    | while read -r rule; do $t $rule; done
done
]]
  run_firewall(p, script, hosts, cb)
end

--- 通信の制限を外す。docker exec が切れてもコンテナ内のプロセスは残ることがあるので、
--- 先に専用ユーザーのプロセスをすべて止め、止められなければ外さない
---@param p devcontainer.Project
---@param cb? fun(ok: boolean)
function M.lift_firewall(p, cb)
  local kill = ([=[
uid=$(id -u %s) || exit 0
for _ in 1 2 3 4 5; do
  pids=$(grep -l "^Uid:[[:space:]]*$uid[[:space:]]" /proc/[0-9]*/status 2>/dev/null | cut -d/ -f3)
  [ -n "$pids" ] || exit 0
  kill -9 $pids 2>/dev/null
  sleep 0.2
done
exit 1
]=]):format(M.user)
  local script = unjump .. [[
for t in iptables ip6tables; do
  $t -L OUTPUT >/dev/null 2>&1 || continue
  unjump
  $t -F NVIM_AGENT 2>/dev/null || true
  $t -X NVIM_AGENT 2>/dev/null || true
done
]]
  local function done(ok)
    if ok then p.agent_active = nil end
    vim.cmd.redrawstatus({ bang = true })
    if cb then cb(ok) end
  end
  tools.exec(p, "root", { "sh", "-c", kill }, function(code)
    if code ~= 0 then
      notify(M.user .. " のプロセスを止められないため、通信の制限を残しました", vim.log.levels.WARN)
      return done(false)
    end
    run_firewall(p, script, {}, done)
  end)
end

--- 普段の Claude の認証と設定を専用ユーザー用にコピーする（ログインは共有する）
---@param p devcontainer.Project
---@param cb fun(ok: boolean, err?: string)
local function prepare_config(p, cb)
  local src, dst = claude.config_dir(p), M.config_dir(p)
  local script = table.concat({
    -- このプロジェクトで普段の Claude をまだ開いていなくても、共有のログインがあれば使う
    claude.sync_auth_script(p, p.remote_user or "root"),
    ("[ -f %s/.credentials.json ] || exit 3"):format(src),
    ("mkdir -p %s"):format(dst),
    ("for i in settings.json CLAUDE.md skills agents; do rm -rf %s/$i; [ ! -e %s/$i ] || cp -a %s/$i %s/; done")
      :format(dst, src, src, dst),
    -- トークンは更新されるので新しい方を使う。コピー先は専用ユーザーが書き換えられるので、
    -- root の cp がシンボリックリンクをたどって別のファイルを上書きしないよう、先に消す
    ("[ %s/.credentials.json -nt %s/.credentials.json ] || { rm -f %s/.credentials.json && cp -p %s/.credentials.json %s/; }")
      :format(dst, src, dst, src, dst),
    ("[ -f %s/.claude.json ] || [ ! -f %s/.claude.json ] || { rm -f %s/.claude.json && cp %s/.claude.json %s/; }")
      :format(dst, src, dst, src, dst),
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
      apply_firewall(p, function(fw_ok)
        -- 制限をかけられなければ起動しない
        if not fw_ok then return fail("通信の制限を設定できませんでした") end
        p.agent_active = true
        vim.cmd.redrawstatus({ bang = true })
        prepare_config(p, function(cfg_ok, cfg_err)
          if not cfg_ok then
            M.lift_firewall(p)
            return fail(cfg_err)
          end
          claude.copy_git_identity(p, M.user, function()
            local _, created = require("devcontainer.terminal").open({
              cmd = {
                "docker", "exec", "-it", "-w", p.root, "-u", M.user,
                "-e", "CLAUDE_CONFIG_DIR=" .. M.config_dir(p),
                "-e", "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1",
                p.container_id, tools.prefix(p) .. "/npm/bin/claude", "--dangerously-skip-permissions",
              },
              cwd = p.root,
              name = "agent",
              key = "agent:" .. p.root,
              root = p.root,
              on_exit = function()
                -- コンテナを止める・作り直すときは、ネットワークごと消えるので外さなくてよい
                if p.stopping then
                  p.agent_active = nil
                  return
                end
                M.lift_firewall(p, function(lifted)
                  if lifted then notify("エージェントが終了したので、通信の制限を外しました") end
                end)
              end,
            })
            if created then notify("エージェントが終了するまで、コンテナ全体の通信を許可リストの宛先に制限します") end
          end)
        end)
      end)
    end)
  end)
end

--- Neovim を閉じるときは、エージェント中のコンテナの制限を外す（Claude も一緒に終わるため）
function M.lift_all_sync()
  for _, p in pairs(require("devcontainer.project").projects) do
    if p.agent_active and p.container_id then
      local done = false
      M.lift_firewall(p, function() done = true end)
      vim.wait(10000, function() return done end)
    end
  end
end

return M
