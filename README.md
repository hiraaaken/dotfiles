# dotfiles

## セットアップ

```sh
git clone https://github.com/hiraaaken/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh            # 基本セット（Homebrew / Brewfile / mise / CLI 系 / symlink）
./install.sh --all      # + Rust, Flutter, Maestro
./install.sh --link-only  # symlink だけ張り直す
```

何度実行しても、入っているものはスキップされる。既存の設定ファイルは `~/.dotfiles-backup/<日時>/` に退避してから symlink を張る。

| 何を | どこで管理 |
| --- | --- |
| brew formula / cask | `Brewfile` |
| node などのランタイム、npm グローバル CLI | `.config/mise/config.toml`（`mise use -g npm:<pkg>` で追記される） |
| curl インストーラ系（Claude Code, agy, Vite+, pnpm, uv tool, skills） | `install.sh` |
| symlink 一覧 | `scripts/link.sh` |

新しくグローバルに何か入れたら、上のどこかに追記する。
各インストーラは `.zshrc` に PATH を追記してくるが、`install.sh` は実行後に元へ戻す。必要な PATH は `.zshrc` / `.zshenv` に手で書く。

マシン固有の設定や秘密情報は `~/.zshrc.local` に書く（リポジトリには入れない）。

## templates/

新しいプロジェクトの `.devcontainer/` の雛形。言語を含まない汎用の土台で、どのプロジェクトでも同じ環境（Debian・git・mise・root 以外のユーザー `dev`）になる。Neovim・Zed・VS Code のどれで開いても動く。

Neovim なら、プロジェクトで `:DevcontainerInit` を実行する（`name` を埋めて書き出し、起動するか確認する）。手でコピーするなら:

```sh
cp -R ~/dotfiles/templates/devcontainer .devcontainer
```

コピーしたあと、`devcontainer.json` の `__NAME__` をプロジェクト名にする。

- 言語やツールは、プロジェクトの `mise.toml` に書く。コンテナを作るときに `post-create.sh` が `mise install` で入れる（手元と同じバージョンになる）
- 依存のインストールなど、プロジェクトの準備は `post-create.sh` の末尾に足す
- 開発サーバーを手元のブラウザで開くなら、`devcontainer.json` の `appPort` を有効にする
- `.git/hooks` などを読み取り専用にする保護と、エージェントの通信制限は、Neovim から開いたときだけ効く（`docs/devcontainer-nvim.md`）

