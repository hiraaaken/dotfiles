-- ターミナル（T1〜T4）。ホストとコンテナのシェルを Snacks.terminal で開閉する
local project = require("devcontainer.project")

local M = {}

--- コンテナのシェルや Claude を開く場所。浮動ウィンドウだとエディタを操作できないので、右に分割する
--- （複数開いたら右の列に上下に積む）
M.win = { position = "right", width = 0.4 }

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

--- ターミナルに移る。隠れていれば開き、いま開いているターミナルなら隠す
---@param cmd? string[]
---@param opts snacks.terminal.Opts
function M.focus(cmd, opts)
  return Snacks.terminal.focus(cmd, opts)
end

function M.host()
  M.focus(nil, { cwd = vim.fn.getcwd() })
end

---@param p devcontainer.Project
local function focus_container(p)
  M.focus(M.container_cmd(p), { cwd = p.root, win = M.win })
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
  require("devcontainer").when_ready(p, focus_container)
end

--- コンテナの準備ができたときに、右にコンテナのシェルを開く。カーソルはエディタに残す
---@param p devcontainer.Project
function M.open_beside(p)
  local cmd, opts = M.container_cmd(p), { cwd = p.root, win = M.win, start_insert = false }
  local term = Snacks.terminal.get(cmd, vim.tbl_extend("force", opts, { create = false }))
  if term and term:win_valid() then return end
  local win = vim.api.nvim_get_current_win()
  term = Snacks.terminal.get(cmd, opts)
  if term and not term:win_valid() then term:show() end
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
  vim.cmd.stopinsert()
end

--- ターミナルからエディタに戻る。分割したターミナルは残し、浮動ウィンドウなら隠す
function M.leave()
  if vim.bo.filetype ~= "snacks_terminal" then return end
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return pcall(vim.api.nvim_win_close, 0, false)
  end
  vim.cmd.stopinsert()
  vim.cmd.wincmd("p")
end

--- devcontainer プロジェクトならコンテナ、それ以外はホスト
function M.auto()
  if vim.bo.filetype == "snacks_terminal" then return M.leave() end
  local p = project.for_buf(0)
  if p and p.mode ~= "host" and require("devcontainer").enabled then return M.container(p) end
  M.host()
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<C-/>", M.auto, { desc = "Terminal (container / host)" })
  map("n", "<C-_>", M.auto, { desc = "which_key_ignore" })
  -- ターミナルからはエディタに戻る（シェルは動き続ける。隠すときはノーマルモードで q）
  map("t", "<C-/>", M.leave, { desc = "Back to editor" })
  map("t", "<C-_>", M.leave, { desc = "which_key_ignore" })
  map("n", "<leader>th", M.host, { desc = "Terminal (host)" })
  map("n", "<leader>tc", function() M.container() end, { desc = "Terminal (container)" })
end

return M
