#!/usr/bin/env bash
# macOS の開発環境セットアップ。何度実行しても入っているものはスキップする。
#
#   ./install.sh               # 基本セット
#   ./install.sh --rust        # + Rust (rustup)
#   ./install.sh --flutter     # + Flutter SDK (~/dev/flutter)
#   ./install.sh --maestro     # + Maestro (モバイル E2E)
#   ./install.sh --all         # 全部
#   ./install.sh --link-only   # シンボリックリンクだけ張り直す
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_RUST=0
WITH_FLUTTER=0
WITH_MAESTRO=0
LINK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --rust) WITH_RUST=1 ;;
    --flutter) WITH_FLUTTER=1 ;;
    --maestro) WITH_MAESTRO=1 ;;
    --all) WITH_RUST=1; WITH_FLUTTER=1; WITH_MAESTRO=1 ;;
    --link-only) LINK_ONLY=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }

if [ "$LINK_ONLY" = 1 ]; then
  "$DOTFILES/scripts/link.sh"
  exit 0
fi

# 各種インストーラは .zshrc などに PATH を追記してくる。
# ~/.zshrc はこのリポジトリへの symlink なので、実行前の内容を退避して最後に戻す。
# 必要な PATH は .zshrc / .zshenv に手で書いてある。
RC_FILES=(.zshrc .zshenv .zprofile)
RC_SNAPSHOT="$(mktemp -d)"
for f in "${RC_FILES[@]}"; do cp "$DOTFILES/$f" "$RC_SNAPSHOT/$f"; done
restore_rc() {
  for f in "${RC_FILES[@]}"; do cp "$RC_SNAPSHOT/$f" "$DOTFILES/$f"; done
  rm -rf "$RC_SNAPSHOT"
  # インストーラが symlink を実ファイルで置き換えていた場合に備えて張り直す
  "$DOTFILES/scripts/link.sh" >/dev/null
}
trap restore_rc EXIT

log "Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "インストール完了後に再度 ./install.sh を実行してください"
  exit 1
fi

log "Homebrew"
if ! has brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

log "symlinks"
"$DOTFILES/scripts/link.sh"

log "brew bundle"
brew bundle --file="$DOTFILES/Brewfile"

log "mise (~/.config/mise/config.toml)"
mise install
# bash で動いているので .zshenv / .zshrc の PATH は効かない。以降の npx や curl で入れた CLI を見つけるために足す
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

log "powerlevel10k"
[ -d "$HOME/powerlevel10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
# zinit とプラグインは初回の zsh 起動時に .zshrc が自動で入れる

log "uv tools"
has specify || uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

log "Claude Code"
has claude || curl -fsSL https://claude.ai/install.sh | bash

log "Antigravity CLI (agy)"
has agy || curl -fsSL https://antigravity.google/cli/install.sh | bash

log "Vite+"
has vp || curl -fsSL https://vite.plus | bash

log "pnpm"
has pnpm || curl -fsSL https://get.pnpm.io/install.sh | sh -

log "agent skills (mattpocock/skills)"
if [ ! -d "$HOME/.agents/skills" ]; then
  npx -y skills add mattpocock/skills -g
fi

if [ "$WITH_RUST" = 1 ]; then
  log "Rust"
  [ -x "$HOME/.cargo/bin/rustup" ] || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

if [ "$WITH_FLUTTER" = 1 ]; then
  log "Flutter"
  [ -d "$HOME/dev/flutter" ] || git clone https://github.com/flutter/flutter.git -b stable "$HOME/dev/flutter"
fi

if [ "$WITH_MAESTRO" = 1 ]; then
  log "Maestro"
  [ -x "$HOME/.maestro/bin/maestro" ] || curl -fsSL https://get.maestro.mobile.dev | bash
fi

log "手動で入れるもの"
has android || echo "- Android CLI: https://developer.android.com/tools/agents/android-cli"
[ -d "$HOME/Library/Android/sdk" ] || echo "- Android Studio / SDK: https://developer.android.com/studio"
[ -f "$HOME/.zshrc.local" ] || echo "- ~/.zshrc.local（マシン固有の設定・秘密情報。リポジトリには入れない）"

log "done. 新しいシェルを開いてください"
