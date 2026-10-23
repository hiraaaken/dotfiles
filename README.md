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

新規プロジェクト作成時、`.devcontainer/` の雛形として使う。

```sh
cp -r ~/dotfiles/templates/devcontainer-node .devcontainer
```

コピー後、プロジェクトに合わせて `name` や `forwardPorts` 等をカスタマイズする。
