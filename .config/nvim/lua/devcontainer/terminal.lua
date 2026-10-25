-- ターミナル（T1〜T4）。ホストとコンテナのシェルを Snacks.terminal で開閉する
local project = require("devcontainer.project")

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devcontainer" })
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

function M.host()
  Snacks.terminal.toggle(nil, { cwd = vim.fn.getcwd() })
end

---@param p devcontainer.Project
local function toggle_container(p)
  Snacks.terminal.toggle(M.container_cmd(p), { cwd = p.root })
end

--- コンテナのシェル。準備中なら待ってから開く（ホストにはフォールバックしない）
---@param p? devcontainer.Project
function M.container(p)
  p = p or project.for_buf(0)
  if not p then
    local root = project.find_root(vim.fn.getcwd())
    p = root and project.get(root)
  end
  if not p then
    return notify("devcontainer のプロジェクトではありません", vim.log.levels.WARN)
  end
  require("devcontainer").when_ready(p, toggle_container)
end

--- devcontainer プロジェクトならコンテナ、それ以外はホスト
function M.auto()
  if vim.bo.filetype == "snacks_terminal" then return M.hide() end
  local p = project.for_buf(0)
  if p and p.mode ~= "host" and require("devcontainer").enabled then return M.container(p) end
  M.host()
end

function M.hide()
  if vim.bo.filetype == "snacks_terminal" then pcall(vim.api.nvim_win_close, 0, false) end
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<C-/>", M.auto, { desc = "Toggle terminal (container / host)" })
  map("n", "<C-_>", M.auto, { desc = "which_key_ignore" })
  -- ターミナルモードからはそのまま隠す（シェルは裏で動き続ける）
  map("t", "<C-/>", M.hide, { desc = "Hide terminal" })
  map("t", "<C-_>", M.hide, { desc = "which_key_ignore" })
  map("n", "<leader>th", M.host, { desc = "Terminal (host)" })
  map("n", "<leader>tc", function() M.container() end, { desc = "Terminal (container)" })
end

return M
