# Neovim Dev Container 連携 要件

VS Code の Dev Containers のように、編集は手元の Neovim で行い、実行環境（LSP・ビルド・テスト・コーディングエージェント）はコンテナ内に隔離する。

- 目的: セキュリティ（エージェントや依存パッケージがホストに触れない）と再現性（プロジェクトごとのツールチェーンを手元に入れない）の両方
- 位置づけ: 自分用。dotfiles の `.config/nvim/lua/devcontainer/` に置く。macOS + colima で動けばよい

## 決定事項

### コンテナ

| # | 決定 |
| --- | --- |
| C1 | コンテナの起動は devcontainer CLI に任せ、既存の `devcontainer.json` にそのまま対応する |
| C2 | プロジェクトの範囲は、開いたファイルから上にたどって最初に見つかった `.devcontainer/`（または `.devcontainer.json`）のあるディレクトリ。マウントは CLI の既定どおり git ルート |
| C3 | 複数プロジェクトを同時に開いたら、それぞれ別のコンテナに対応させる |
| C4 | `read-configuration` で得た設定に、マウント先をホストと同じ絶対パスにする設定（`workspaceMount` / `workspaceFolder`）とツール・Claude 用の名前付きボリューム（`mounts`）を足し、`--override-config` で渡す。LSP のパス変換はしない。`NET_ADMIN` はプロジェクトのコンテナには付けず、A5 の通信制限はネットワークを共有するヘルパーコンテナから設定する（イメージに iptables が無くてよく、コンテナ内の root でもルールを変えられない） |
| C5 | `devcontainer.json` のあるプロジェクトを開くと起動するか確認する。選択肢は「起動する / 常に起動する / 今回は使わない / このプロジェクトでは使わない」。「常に」と「使わない」はプロジェクトごとに state ディレクトリへ保存し、`:DevcontainerForget` で消せる |
| C6 | ビルドは非同期で行い、進み具合を通知する。ログは `:DevcontainerLog` で見られる |
| C7 | Neovim を閉じてもコンテナは止めない |
| C8 | 止まっているコンテナは再開する。`devcontainer.json` が前回の起動時から変わっていたら作り直すか確認する |
| C9 | 起動に失敗したら通知してログを開く。LSP は手元にフォールバックせず、起動しないまま |

### LSP

| # | 決定 |
| --- | --- |
| L1 | コンテナのプロジェクト配下のバッファでは、プロジェクト用の LSP をすべて `docker exec` 経由でコンテナ内で動かす。それ以外のバッファは手元で動かす |
| L2 | Copilot は常に手元で動かす（コードを実行せず、ファイルの中身を読むだけのため） |
| L3 | コンテナが起動するまで、プロジェクト配下のバッファでは LSP を起動しない |
| L4 | LSP 本体とそれを動かす専用の Node は、プラグインが名前付きボリュームに入れ、全コンテナで共有する。プロジェクトの Node とは混ぜない |
| L5 | プロジェクトの `node_modules` に TypeScript があれば、そちらを優先して使う |
| L6 | elm や Java など、LSP の動作に必要なものがコンテナにない場合は警告を出し、その LSP は起動しない |

### ターミナル

| # | 決定 |
| --- | --- |
| T1 | `<C-/>`: devcontainer プロジェクトではコンテナのシェル、それ以外ではホストのシェルを開く |
| T2 | `<leader>th` はどこでもホストのシェル、`<leader>tc` はどこでもコンテナのシェルを開く |
| T3 | ターミナルモードからも `<C-/>` で閉じられる |
| T4 | コンテナの準備ができる前にコンテナのシェルを開こうとしたら「起動中です」と出して待たせる。ホストのシェルにはフォールバックしない |

### エージェント（Claude Code）

| # | 決定 |
| --- | --- |
| A1 | Claude Code は名前付きボリュームに入れ、全コンテナで共有する。Neovim 内のターミナルで、コンテナ内の Claude を使う |
| A2 | 認証はコンテナ内で一度ログインし、ボリュームに保存する。ホストの `~/.claude` はマウントしない |
| A3 | settings.json・skills・agents・CLAUDE.md はコンテナ作成時にホストからコピーする。`:DevcontainerSyncClaude` で再同期できる |
| A4 | devcontainer プロジェクトでは、ホストの Claude（claudecode.nvim の `<leader>ac` など）を起動できないようにする |
| A5 | エージェントに任せるモードでは、sudo を使えない専用ユーザーで Claude を動かす。通信は、プラグインが root として外から設定した許可リストの宛先にだけ制限する。普段は制限しない |

### git

| # | 決定 |
| --- | --- |
| G1 | コンテナ内に push できる認証情報を置かない。commit まではコンテナ内、push はホストから |
| G2 | commit 用に `user.name` と `user.email` だけをホストからコピーする |

## 起動の流れ

1. `nvim .` でプロジェクトを開く
2. `.devcontainer/` が見つかり、未設定なら起動するか確認する（C5）
3. 裏でビルドと起動。この間も編集はできるが、プロジェクトの LSP は動かない（C6, L3）
4. 初回だけ、ツールボリュームへ LSP・Node・Claude Code を入れ、Claude の設定と git の名前・メールをコピーする（L4, A1, A3, G2）
5. 起動が完了したら、開いているバッファにコンテナ内の LSP をつなぎ、ステータスラインに表示する
6. 2 回目以降は、動いていれば数秒、止まっていれば再開して十数秒

## コマンド

| コマンド | 用途 |
| --- | --- |
| `:DevcontainerUp` | 手動で起動する |
| `:DevcontainerRebuild` | 作り直す |
| `:DevcontainerStop` | 止める |
| `:DevcontainerLog` | ビルドや起動のログを見る |
| `:DevcontainerForget` | 「常に起動 / 使わない」の記憶を消す |
| `:DevcontainerSyncClaude` | Claude の設定をホストから同期し直す |
| `:DevcontainerAgent` | エージェントに任せるモードで Claude を起動する（A5） |

## キーマップ

| キー | 用途 |
| --- | --- |
| `<C-/>` | devcontainer プロジェクトではコンテナ、それ以外はホストのシェル（T1, T3） |
| `<leader>th` / `<leader>tc` | ホスト / コンテナのシェル（T2） |
| `<leader>ac` / `<leader>ar` / `<leader>aC` | devcontainer プロジェクトではコンテナ内の Claude、それ以外はホストの Claude（A1, A4） |
| `<leader>aA` | `:DevcontainerAgent` |

## 実装の段階

すべて実装済み。

| 段階 | 内容 | ファイル |
| --- | --- | --- |
| M1 | 検出・確認・`up`（同じパスへのマウント）・ログ / 停止 / 記憶の消去 | `init.lua` `project.lua` `cli.lua` |
| M2 | ターミナル（T1〜T4） | `terminal.lua` |
| M3 | LSP をコンテナで動かす（L1〜L6） | `lsp.lua` `tools.lua` |
| M4 | コンテナ内の Claude（A1〜A4, G2） | `claude.lua` `tools.lua` |
| M5 | エージェントに任せるモード（A5） | `agent.lua` |

## 実装メモ

決定事項を実装に落とすときに決めたこと。

- **ボリューム**: `nvim-devcontainer-tools`（`/opt/nvim-dc`、読み取り専用でマウント）と `nvim-devcontainer-claude`（`/opt/nvim-dc-claude`）。ツールは `node:22-slim`（musl のイメージなら `node:22-alpine`）のヘルパーコンテナから入れる。中身は手元の mason の npm パッケージと同じバージョンに `typescript@5` と Claude Code を足したもの。一覧が変わったら入れ直す。ボリュームの無い既存コンテナは、同じパスのマウントが無いときと同じく作り直すか確認する
- **LSP**: `vim.lsp.start` を包んで、`docker exec -i` 経由の cmd に差し替える。コンテナから見えない手元の PID で LSP が終了しないよう、`processId` は送らない。cmd が関数の lspconfig 設定（ts_ls など）は、関数版と同じく `node_modules/.bin` を優先する。コマンドがコンテナに無ければ（mason の npm 以外の LSP や `elm` など）警告して起動しない（L6）
- **確認**: C5 の確認を閉じたら未回答のままにする。答えるまではプロジェクトの LSP もホストの Claude も起動しない（`:DevcontainerUp` で起動できる）
- **ツールの更新**: インストールは 15 分で打ち切る。ツールのボリュームは読み取り専用なので、Claude Code の自動更新は止めている
- **TypeScript**: プロジェクトの `node_modules/typescript` があればそれを、無ければボリュームの `typescript@5` を使う（TypeScript 7 には `tsserver.js` が無い）
- **Claude の認証**: 設定は `CLAUDE_CONFIG_DIR=/opt/nvim-dc-claude/config`。認証ファイルは 0600 なので、開くたびにそのコンテナのユーザーへ持ち主を合わせる
- **エージェント**: 専用ユーザーは `nvim-agent`。sudo が使えたら中止する。認証は普段の設定から `/opt/nvim-dc-claude/agent` へコピーし、トークンは新しい方を両方向に取り込む。`--dangerously-skip-permissions` で起動する
- **通信制限**: `nvim-agent` の uid の OUTPUT だけを、ループバック・DNS・許可リストの宛先に制限する（IPv6 は DNS 以外すべて拒否）。宛先は起動のたびに引き直す。既定は Anthropic の API と認証・テレメトリの宛先で、`vim.g.devcontainer_agent_allowlist` で足せる。ルールを設定できなければ起動しない
- **git**: `safe.directory=*` を system に設定する（マウントしたファイルの持ち主がコンテナのユーザーと違って見えるため）
