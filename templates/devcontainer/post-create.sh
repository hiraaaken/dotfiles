#!/bin/sh
# コンテナを作ったあとに一度だけ動く（作業ディレクトリはプロジェクトのルート）
set -eu

# git の名前とメール（initializeCommand が手元で書き出したもの。無ければ飛ばす）
identity=.devcontainer/.local/git-identity
if [ -s "$identity" ]; then
  name=$(sed -n 1p "$identity")
  email=$(sed -n 2p "$identity")
  [ -n "$name" ] && git config --global user.name "$name"
  [ -n "$email" ] && git config --global user.email "$email"
fi
# マウントしたファイルの持ち主がコンテナのユーザーと違って見えても、git を使えるようにする
git config --global --add safe.directory "$PWD"

# プロジェクトの mise.toml（.tool-versions）のツールを入れる
if [ -f mise.toml ] || [ -f .mise.toml ] || [ -f .tool-versions ]; then
  mise trust
  mise install
fi

# ここにプロジェクトの準備を足す。例（pnpm）:
#   CI=true pnpm install --ignore-scripts
# --ignore-scripts は、prepare などが .git の設定や hooks を書き換えようとして失敗するのを避けるため
# （Neovim から開くと、コンテナからは読み取り専用になっている）
