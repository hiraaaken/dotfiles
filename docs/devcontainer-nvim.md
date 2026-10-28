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
| C8 | 止まっているコンテナは再開する。`devcontainer.json` が前回の起動時から変わっていたら作り直すか確認する。「そのまま起動する」を選んだら、作り直すまで次回も確認する |
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
| T3 | ターミナルモードからの `<C-/>` は、ターミナルを残したままエディタに戻る（隠すときはノーマルモードで `q`） |
| T5 | ターミナルは右の列（ターミナルのペイン）に開く（浮動ウィンドウだとエディタを操作できないため）。コンテナのシェル・Claude・エージェントも同じペインに開く。コンテナの準備ができたら、右にコンテナのシェルを開き、カーソルはエディタに残す（`vim.g.devcontainer_auto_terminal = false` で開かない） |
| T6 | ペインの中では、バッファのようにターミナルを追加・切り替えでき、上下に分割できる。ペインの上に、開いているターミナルの一覧を出す。シェルが正常に終わったら閉じる。コンテナを止める・再起動する・作り直すときは、そのプロジェクトのターミナル（シェル・Claude・エージェント）を先に閉じる |
| T7 | コンテナのシェルからも `claude` でコンテナ内の Claude（`<leader>ac` と同じ設定・ログイン）を使える。bash のシェルは、コンテナの中だと分かるプロンプト（`⬢ プロジェクト/パス  ブランチ`）にする |
| T4 | コンテナの準備ができる前にコンテナのシェルを開こうとしたら「起動中です」と出して待たせる。ホストのシェルにはフォールバックしない |

### エージェント（Claude Code）

| # | 決定 |
| --- | --- |
| A1 | Claude Code は名前付きボリュームに入れ、全コンテナで共有する。Neovim 内のターミナルで、コンテナ内の Claude を使う |
| A2 | 認証はコンテナ内で一度ログインし、ボリュームに保存する。ホストの `~/.claude` はマウントしない。全コンテナで共有するのはログインだけで、Claude の設定や履歴はプロジェクトごとに分ける（あるプロジェクトで仕込まれた hooks や MCP サーバーが、他のプロジェクトで動かないように） |
| A3 | settings.json・skills・agents・CLAUDE.md はコンテナ作成時にホストからコピーする。`:DevcontainerSyncClaude` で再同期できる |
| A4 | devcontainer プロジェクトでは、ホストの Claude（claudecode.nvim の `<leader>ac` など）を起動できないようにする |
| A5 | エージェントに任せるモードでは、sudo を使えない専用ユーザーで Claude を動かす。エージェントが動いている間は、コンテナ全体（uid を問わない）の通信を、プラグインが root として外から設定した許可リストの宛先にだけ制限する。エージェントが終了したら外す。普段は制限しない |

### node_modules

| # | 決定 |
| --- | --- |
| N1 | 手元に node_modules が無ければ（または空なら）、プロジェクトごとの名前付きボリュームを node_modules に重ね、手元には作らない（コンテナ用の Linux のバイナリが手元に入らないように） |
| N2 | 手元に node_modules があれば（手元でも開発するプロジェクト）、今までどおりそれをコンテナと共有する |
| N3 | ボリュームのときは、依存の解決をコンテナの LSP に任せ、定義へ飛んだ先などの node_modules のファイルはコンテナから読む（読み取り専用） |

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
| `:DevcontainerRestart` | 再起動する（止めてから起動する。設定が変わっていれば作り直すか確認する） |
| `:DevcontainerLog` | ビルドや起動のログを見る |
| `:DevcontainerForget` | 「常に起動 / 使わない」の記憶を消す |
| `:DevcontainerSyncClaude` | Claude の設定をホストから同期し直す |
| `:DevcontainerAgent` | エージェントに任せるモードで Claude を起動する（A5） |

## キーマップ

| キー | 用途 |
| --- | --- |
| `<C-/>` | devcontainer プロジェクトではコンテナ、それ以外はホストのシェルに移る。ターミナルからはエディタに戻る（T1, T3） |
| `<leader>th` / `<leader>tc` | ホスト / コンテナのシェル（T2） |
| `<leader>tn` / `<leader>ts` | 新しいターミナルをペインに開く / ペインを上下に分割して開く（T6） |
| `<leader>tx` / `<leader>tq` | いまのターミナルを閉じる / ペインを閉じる（ターミナルは動き続ける） |
| `]t` / `[t`（ターミナルのノーマルモード） | ペインのターミナルを切り替える。ターミナルモードからノーマルモードへは `<Esc><Esc>` |
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
| M6 | node_modules をコンテナの中だけに置く（N1〜N3） | `node_modules.lua` |

## 実装メモ

決定事項を実装に落とすときに決めたこと。

- **ボリューム**: `nvim-devcontainer-tools`（`/opt/nvim-dc`、読み取り専用でマウント）と `nvim-devcontainer-claude`（`/opt/nvim-dc-claude`）。ツールは `node:22-slim`（musl のイメージなら `node:22-alpine`）のヘルパーコンテナから入れる。中身は手元の mason の npm パッケージと同じバージョンに `typescript@5` と Claude Code を足したもの。一覧が変わったら入れ直す。入れ直しはバージョンごとのディレクトリ（`/opt/nvim-dc/glibc.<stamp>`）に入れてシンボリックリンクで切り替え、直前のバージョンは残す（他のコンテナで動いている LSP が使っているため）。ボリュームの無い既存コンテナは、同じパスのマウントが無いときと同じく作り直すか確認する
- **LSP**: `vim.lsp.start` を包んで、`docker exec -i` 経由の cmd に差し替える。コンテナから見えない手元の PID で LSP が終了しないよう、`processId` は送らない。cmd が関数の lspconfig 設定（ts_ls など）は、関数版と同じく `node_modules/.bin` を優先する。コマンドがコンテナに無ければ（mason の npm 以外の LSP や `elm` など）警告して起動しない（L6）。oxfmt（Vite+ の整形）は mason で入れず、プロジェクトの `node_modules/.bin`、無ければ `vite-plus` の実体の隣（pnpm では `.bin` に置かれないため）から探す
- **確認**: C5 の確認を閉じたら未回答のままにする。答えるまではプロジェクトの LSP もホストの Claude も起動しない（`:DevcontainerUp` で起動できる）
- **ツールの更新**: インストールは 15 分で打ち切る。ツールのボリュームは読み取り専用なので、Claude Code の自動更新は止めている
- **TypeScript**: プロジェクトの `node_modules/typescript` があればそれを、無ければボリュームの `typescript@5` を使う（TypeScript 7 には `tsserver.js` が無い）
- **Claude の認証**: 設定はプロジェクトごとに `CLAUDE_CONFIG_DIR=/opt/nvim-dc-claude/projects/<ルートの sha256 の先頭 16 文字>/config`。共有のログインは `/opt/nvim-dc-claude/auth`（root だけが読み書きする）に置き、開くたびに新しい方の `.credentials.json` を両方向に取り込む（どこかで `/login` すれば全プロジェクトに行き渡る）。新しいプロジェクトの `.claude.json` には、アカウントと初回設定の項目（`oauthAccount` など）だけを引き継ぐ。シンボリックリンクは読まない。以前の `/opt/nvim-dc-claude/config` のログインは初回に `auth` へ移す（旧ディレクトリは残るので、不要なら消してよい）。共有するログイン自体は、どのプロジェクトのコンテナからも読み書きできるので、トークンの窃取やすり替えは防げない
- **エージェント**: 専用ユーザーは `nvim-agent`。sudo が使えたら中止する。認証はそのプロジェクトの普段の設定から `/opt/nvim-dc-claude/projects/<…>/agent` へコピーし、トークンは普段の設定の方が新しければ取り込む。逆向き（エージェント → 普段）は取り込まない（エージェントが別のアカウントのトークンにすり替えられるため）。エージェントのセッション中にトークンが更新されると、普段の Claude で `/login` し直しが必要になることがある。`--dangerously-skip-permissions` で起動する
- **通信制限**: エージェントの起動中はコンテナ全体の OUTPUT を、ループバック・コンテナの DNS サーバー（`/etc/resolv.conf`）・許可リストの宛先に制限する（IPv6 も同様）。宛先は起動のたびに引き直す。既定は Anthropic の API と認証の宛先で、誰でも送れるテレメトリの宛先（statsig.com・sentry.io）は持ち出しに使えるので入れず、`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` で止める。`vim.g.devcontainer_agent_allowlist` で足せる。ルールを設定できなければ起動しない。`nvim-agent` の uid だけに掛けると、エージェントが書いたファイル（`eslint.config.js` や `node_modules/.bin` など）を普段のユーザーや LSP が実行して抜けられるため、全体に掛ける。チェーンは `iptables-restore` で一度に入れ替え、引き直しの途中で制限が外れないようにする。エージェントのターミナルが終了したとき（と Neovim を閉じるとき）に、`nvim-agent` のプロセスをすべて止めてから制限を外す（`docker exec` が切れてもコンテナ内のプロセスは残ることがあるため）。止められなければ制限を残す。Neovim が異常終了したときは、次にエージェントを開いて終了するか、コンテナを再起動するまで制限が残る。エージェントの終了後に、エージェントが書いたファイルを実行すると制限は掛からない
- **node_modules**: ルートに `package.json` があり、手元の node_modules が無いか空なら、`nvim-devcontainer-nm-<ルートの sha256 の先頭 16 文字>` を重ねる。どちらにするかは起動のたびに手元の状態で決める（ボリュームを重ねたコンテナがあると、手元の node_modules は空のマウント先になるので変わらない）。手元の node_modules を消すと、次の起動で作り直すか確認する。ボリュームは作り直しても残す（入れ直しが速いように）。新しいボリュームは root の持ち物になり remoteUser の `pnpm install` が失敗するので、`up` の前にヘルパーコンテナでルートを 1777（スティッキー）にする。ライフサイクルコマンドの流れは変えない。LSP が使う `node_modules/.bin` のコマンドと TypeScript は、手元ではなくコンテナの中で探す（ロックファイルの更新時刻ごとに覚えるので、依存を入れ直すと探し直す）。node_modules 配下のファイルは `BufReadCmd` で `docker exec cat` して読み、書き込み・スワップ・アンドゥ・モードラインを止める。防げない・できないもの: 手元で commit すると、node_modules を使う git hooks（`vp staged` など）が動かない（commit はコンテナ内で）。pnpm workspace の `packages/*/node_modules` は手元に作られる（ルートだけが対象）。`nvim-agent` は node_modules に新しいファイルは作れるが、普段のユーザーが入れたものは書き換えられない
- **ホストの保護**: プロジェクトのマウントは書き込めるので、ホストで実行されるファイルは読み取り専用で重ねてマウントする。`.git/config`・`.git/config.worktree`・`.git/hooks`・`.git/lazygit.yml`・作業ツリー内の `core.hooksPath`（`.husky` など）・`.devcontainer` / `.devcontainer.json`。無いものは先に手元で作る（コンテナ内で作られないように）。既存コンテナにこれらが無ければ作り直すか確認する。コンテナ内では `git config`（リポジトリの設定）は書けないが、commit はできる。防げないもの: `initializeCommand` が作業ツリーのスクリプトを呼ぶ場合、`include.path` で作業ツリーのファイルを読む場合、ホストで作業ツリーのファイルを実行する他のツール（mise の設定など）
- **ターミナル**: コンテナのシェルは、プロジェクトの `node_modules/.bin` を `PATH` の先頭に足して開く（`vp` などをそのまま使えるように）。ペインに開くコマンドはすべて `TERM=xterm-256color`・`COLORTERM=truecolor` で動かす（`docker exec -it` は `TERM=xterm` にするので、色が減り Debian の bashrc もプロンプトに色を付けない）。シェルは `LANG` が無ければ `C.UTF-8` にする（日本語の入力が崩れないように）
- **シェルの claude**: シェルごとにコンテナの一時ディレクトリを作り、ボリュームの `claude` へのリンクを置いて `PATH` の末尾に足す。ボリュームの `npm/bin` ごと足すと、LSP 用の `tsc` などがプロジェクトのツールに見えるので足さない。`CLAUDE_CONFIG_DIR` などは `<leader>ac` と同じものを渡し、シェルを新しく開く前に共有のログインを取り込む。エージェント用の設定は使わない
- **シェルの見た目**: bash なら `lua/devcontainer/bashrc` を rcfile にして開く（ログインシェルと同じく `/etc/profile` と `~/.profile` などを読んでから、`PATH` とプロンプトを整える）。rcfile は開くたびに一時ディレクトリへ書き出し、共有のボリュームには置かない（どのプロジェクトのコンテナからも書けるので、他のプロジェクトのシェルで動くコードを仕込めてしまう）。ブランチは `git symbolic-ref` だけで出し、作業ツリーの変更は見ない（バインドマウントが遅いため）。zsh のイメージはイメージ側のプロンプトに任せる
- **git**: `safe.directory=*` を system に設定する（マウントしたファイルの持ち主がコンテナのユーザーと違って見えるため）

## 検証

`node:22-bookworm` のテスト用コンテナ（colima, aarch64）で確認した。

- コンテナ内の root から `.git/config`・hooks・`.husky`・`.devcontainer` に書き込めず、commit はできること。手元で `.git/config` を書き換えるとコンテナからも見えること
- `ClaudeCodeAdd` / `ClaudeCodeSend` / `ClaudeCodeTreeAdd` でもホストの Claude が起動しないこと
- 同じ root でも、手元とコンテナの LSP クライアントが使い回されないこと。`root_markers` で root を決める LSP（cssls など）が、その root で動くこと
- 共有のログインの移行・プロジェクト間の伝播、シンボリックリンクを読まないこと、`mcpServers` などが引き継がれないこと、`nvim-agent` から読めないこと
- エージェント用の設定を root がコピーするとき、`nvim-agent` が置いたシンボリックリンクをたどらないこと
- ツールの入れ直しで、旧構成（実ディレクトリ）から移行し、直前のバージョンが残ること
- pnpm で Vite+ を入れたプロジェクトで、oxfmt がコンテナ内で動き、保存時に整形されること。oxfmt を使わないプロジェクトでは保存時に整形しないこと
- C5 の確認の各選択肢・閉じたとき、`:DevcontainerForget` / `Up` / `Stop` / `Rebuild`（LSP の終了とつなぎ直し）
- コンテナのシェル（起動待ちを含む）、ホストのシェル、ターミナルモードからの `<C-/>`
- コンテナのシェルで `claude` が動き、`node_modules/.bin` が先頭・`TERM=xterm-256color`・`LANG=C.UTF-8` になること。プロンプトにプロジェクトからのパスとブランチが出て、失敗したら ❯ が赤になること。終了すると一時ディレクトリが消えること
- ts_ls・vue_ls などがコンテナ内で動き診断を返すこと、起動前・確認前は LSP が動かないこと、Copilot は手元のまま
- Claude の設定と git の名前・メールのコピー、ホストの Claude の封鎖
- コンテナ内で `/login` した本物の認証で、`nvim-agent` の Claude が許可リスト内の API に応答し、許可リスト外（example.com）や DNS サーバー以外の 53 番には繋がらないこと。起動中は root や普段のユーザーも制限され、終了後は `nvim-agent` のプロセスが止まって制限が外れること。引き直しても重複しないこと
