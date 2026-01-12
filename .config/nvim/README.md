# Neovim 設定

このディレクトリには Neovim の設定ファイルが含まれています。プラグイン管理には [lazy.nvim](https://github.com/folke/lazy.nvim) を使用しています。

## ディレクトリ構造

```
.config/nvim/
├── init.lua                    # エントリーポイント
├── lazy-lock.json              # プラグインバージョン固定
├── lua/
│   ├── config/
│   │   ├── lazy.lua            # lazy.nvim ブートストラップ
│   │   └── lsp.lua             # LSP キーマップ・診断設定
│   ├── core/
│   │   ├── options.lua         # Neovim オプション
│   │   ├── keymaps.lua         # コアキーマップ
│   │   └── autocmds.lua        # 自動コマンド
│   └── plugins/                # プラグイン設定
│       └── lsp/                # LSP 関連プラグイン
└── after/
    └── lsp/                    # LSP サーバー個別設定
```

## プラグイン一覧

### カラースキーム・UI

#### kanagawa.nvim
- **リポジトリ**: `rebelot/kanagawa.nvim`
- **概要**: 日本の風景にインスパイアされた美しいカラースキーム
- **設定**:
  - テーマ: wave
  - コメント: イタリック
  - ステートメント: ボールド
  - 背景: 透明

#### lualine.nvim
- **リポジトリ**: `nvim-lualine/lualine.nvim`
- **概要**: 高機能なステータスライン
- **設定**:
  - テーマ: Kanagawa
  - 左セクション: モード、ブランチ、差分、診断
  - 中央: ファイル名（パス付き）
  - 右セクション: エンコーディング、ファイルフォーマット、進捗
  - タブライン: バッファリスト表示

#### noice.nvim
- **リポジトリ**: `folke/noice.nvim`
- **概要**: コマンドライン・通知の UI 改善
- **依存**: `nui.nvim`, `nvim-notify`
- **機能**:
  - 検索・コマンドパレットの改善
  - 長いメッセージを新しいウィンドウで表示
  - LSP ドキュメントのスタイリング

### エディタ機能

#### nvim-treesitter
- **リポジトリ**: `nvim-treesitter/nvim-treesitter`
- **概要**: 高度なシンタックスハイライトと AST パース
- **対応言語**: JSON, JavaScript, TypeScript, TSX, YAML, HTML, CSS, Markdown, Bash, Lua, Vim, Vimdoc, Haskell

#### which-key.nvim
- **リポジトリ**: `folke/which-key.nvim`
- **概要**: キーマップのヘルプ表示
- **キーマップ**: `<leader>?` で表示
- **タイムアウト**: 500ms

#### flash.nvim
- **リポジトリ**: `folke/flash.nvim`
- **概要**: 高速ジャンプ・モーションプラグイン
- **キーマップ**: `<CR>` でジャンプモード起動
- **設定**: ラベルをカーソル前に表示

#### mini.pairs
- **リポジトリ**: `echasnovski/mini.pairs`
- **概要**: 括弧・クォートの自動補完
- **トリガー**: 挿入モードで自動

#### mini.bufremove
- **リポジトリ**: `echasnovski/mini.bufremove`
- **概要**: 分割を閉じずにバッファを削除

### ファイル・バッファ管理

#### oil.nvim
- **リポジトリ**: `stevearc/oil.nvim`
- **概要**: バッファスタイルのファイルエクスプローラー
- **キーマップ**: `<leader>e` で開く
- **依存**: `nvim-web-devicons`, `oil-git-status`
- **設定**:
  - Git ステータス表示
  - 隠しファイル表示
  - LSP 対応のファイル操作
  - .DS_Store スキップ
  - 削除はゴミ箱へ

| キー | 動作 |
|------|------|
| `<CR>` | ファイルを開く |
| `-` | 親ディレクトリ |
| `<C-p>` | プレビュー |
| `<C-s>` | 水平分割で開く |
| `<C-h>` | 垂直分割で開く |
| `<C-t>` | 新タブで開く |

#### snacks.nvim
- **リポジトリ**: `folke/snacks.nvim`
- **概要**: 多機能ユーティリティ（ピッカー、ダッシュボード、Git、ターミナル等）
- **優先度**: 1000（最初に読み込み）

**ダッシュボード機能**:
- 起動時に最近のファイル表示
- クイックアクション（ファイル検索、新規作成、grep、設定、セッション、Lazy、終了）

**ピッカーキーマップ**:

| キー | 動作 |
|------|------|
| `<leader><space>` | スマートファイル検索 |
| `<leader>,` | バッファ一覧 |
| `<leader>/` | Grep |
| `<leader>ff` | ファイル検索 |
| `<leader>fr` | 最近のファイル |
| `<leader>fg` | Git ファイル |

**Git 連携**:

| キー | 動作 |
|------|------|
| `<leader>gb` | ブランチ一覧 |
| `<leader>gl` | Git ログ |
| `<leader>gs` | Git ステータス |
| `<leader>gB` | Git blame |

**その他の機能**:
- `<C-/>`: ターミナルトグル
- `<leader>z`: Zen モード
- `<leader>u*`: 各種トグル（スペル、ワードラップ、診断等）

### 補完

#### nvim-cmp
- **リポジトリ**: `hrsh7th/nvim-cmp`
- **概要**: 高機能な補完エンジン
- **依存プラグイン**:
  - `cmp-buffer`: バッファ内テキスト
  - `cmp-path`: ファイルパス
  - `cmp-nvim-lsp`: LSP 補完
  - `LuaSnip`: スニペットエンジン
  - `cmp_luasnip`: スニペット補完
  - `friendly-snippets`: スニペットライブラリ
  - `lspkind`: VS Code アイコン

**補完キーマップ**:

| キー | 動作 |
|------|------|
| `<C-k>` | 前の候補 |
| `<C-j>` | 次の候補 |
| `<C-Space>` | 補完表示 |
| `<C-e>` | メニュー閉じる |
| `<CR>` | 候補確定 |

### AI 支援

#### copilot.lua
- **リポジトリ**: `zbirenbaum/copilot.lua`
- **概要**: GitHub Copilot による AI コード補完
- **キーマップ**:
  - `<C-s>`: 提案を確定
  - `<C-n>`: 次の提案
  - `<C-l>`: 提案を閉じる
- **設定**: 全ファイルタイプで自動トリガー有効

#### CopilotChat.nvim
- **リポジトリ**: `CopilotC-Nvim/CopilotChat.nvim`
- **概要**: Copilot とのチャットインターフェース
- **キーマップ**: `cpc` でチャット開始
- **依存**: copilot.lua, plenary.nvim

#### claudecode.nvim
- **リポジトリ**: `coder/claudecode.nvim`
- **概要**: Claude Code との連携
- **キーマップ**:
  - `<leader>ac`: Claude Code トグル
  - `<leader>as`（ビジュアル）: 選択範囲を送信
- **設定**: Diff ウィンドウは下部に配置

### LSP

#### Mason + mason-lspconfig + nvim-lspconfig
- **概要**: LSP サーバーの管理と設定
- **自動インストールサーバー**:
  - `ts_ls`: TypeScript / JavaScript
  - `html`: HTML
  - `cssls`: CSS
  - `tailwindcss`: Tailwind CSS
  - `svelte`: Svelte
  - `lua_ls`: Lua
  - `graphql`: GraphQL
  - `emmet_ls`: Emmet
  - `prismals`: Prisma
  - `pyright`: Python
  - `eslint`: ESLint

**LSP キーマップ**:

| キー | 動作 |
|------|------|
| `gd` | 定義へジャンプ |
| `gD` | 宣言へジャンプ |
| `gr` / `gR` | 参照一覧 |
| `gi` | 実装へジャンプ |
| `gt` | 型定義へジャンプ |
| `<leader>ca` | コードアクション |
| `<leader>rn` | リネーム |
| `<leader>D` | バッファ診断 |
| `<leader>d` | 行診断 |

## コアキーマップ

**リーダーキー**: `Space`

### 挿入モード

| キー | 動作 |
|------|------|
| `jj` | 挿入モード終了 |

### ウィンドウ操作

| キー | 動作 |
|------|------|
| `<leader>sv` | 垂直分割 |
| `<leader>sh` | 水平分割 |
| `<leader>se` | 分割サイズ均等化 |
| `<leader>sx` | 分割を閉じる |
| `<C-h/j/k/l>` | ウィンドウ間移動 |

### バッファ操作

| キー | 動作 |
|------|------|
| `H` | 前のバッファ |
| `L` | 次のバッファ |
| `<leader>q` | バッファを閉じる（保存確認） |
| `<leader>Q` | ウィンドウを閉じる/終了 |

### 編集

| キー | 動作 |
|------|------|
| `<leader>h` | 行頭へ移動 |
| `<leader>l` | 行末へ移動 |
| `<leader>w` | ファイル保存 |
| `<leader>;` | 最後のコマンドを再実行 |

## オプション設定

- **行番号**: 相対行番号 + 絶対行番号
- **インデント**: 2 スペース（タブ→スペース変換）
- **カーソルライン**: ハイライト有効
- **検索**: 大文字小文字を区別しない（スマートケース）
- **スクロール**: 上下 3 行オフセット
- **折り返し**: 無効
- **分割**: 右・下に新規ウィンドウ
- **クリップボード**: OS と共有
