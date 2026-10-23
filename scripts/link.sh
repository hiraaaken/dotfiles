#!/usr/bin/env bash
# dotfiles のシンボリックリンクを張る。何度実行しても同じ結果になる。
# 既存のファイル（リンク先が違う symlink を含む）は ~/.dotfiles-backup/<日時>/ に退避する。
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# link <リポジトリ内のパス> <$HOME からのパス>
link() {
  local src="$DOTFILES/$1" dst="$HOME/$2"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok      ~/$2"
    return
  fi

  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$(dirname "$BACKUP_DIR/$2")"
    mv "$dst" "$BACKUP_DIR/$2"
    echo "backup  ~/$2 -> $BACKUP_DIR/$2"
  fi
  # 既存のものは退避済みなので -f/-n は不要（ディレクトリ symlink の中にリンクが作られる事故も防げる）
  ln -s "$src" "$dst"
  echo "link    ~/$2"
}

# shell
link .zshenv                      .zshenv
link .zprofile                    .zprofile
link .zshrc                       .zshrc
link .p10k.zsh                    .p10k.zsh

# git / npm
link .gitconfig                   .gitconfig
link .config/git/ignore           .config/git/ignore
link .npmrc                       .npmrc

# tools
link .config/mise/config.toml     .config/mise/config.toml
link .config/nvim                 .config/nvim
link .config/ghostty/config       .config/ghostty/config
link .config/zed/settings.json    .config/zed/settings.json
link .config/zed/keymap.json      .config/zed/keymap.json

# Claude Code（リポジトリ直下の .claude/ はこのリポジトリ用のプロジェクト設定なので別ディレクトリに置いている）
link claude/settings.json         .claude/settings.json
link claude/statusline-command.sh .claude/statusline-command.sh
