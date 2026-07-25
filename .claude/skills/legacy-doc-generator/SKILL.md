---
name: legacy-doc-generator
description: >
  Generate system documentation (overview, architecture design, API spec, database
  design, module design) from legacy Java/Kotlin + Spring Boot project codebases.
  No external runtime required — uses only bash commands (find, grep, cat) and
  Claude's own code reading ability. Triggers when user asks to: generate documentation
  from existing code, create system overview or design documents from a legacy project,
  reverse-engineer architecture from source code, analyze a Spring Boot project
  structure, produce technical documentation from an undocumented codebase.
  Target stack: Java/Kotlin with Spring Boot, Gradle or Maven. Output: Markdown.
  Japanese triggers: 設計書生成、要件定義書作成、システム概要書、
  レガシーコードからドキュメント生成、リバースエンジニアリング。
---

# Legacy Documentation Generator

レガシー Spring Boot プロジェクトのコードベースを解析し、技術ドキュメントを自動生成するスキル。
**外部ランタイム不要** — bash コマンドと Claude のコード読解力のみで動作する。

## 重要原則

- 生成ドキュメントでは**事実**と**推測**を分離。推測には `【推測】` を付与
- 生成物は「叩き台」であり正式な設計書ではない旨を全文書冒頭に明記
- セキュリティ関連の値（パスワード、トークン等）は出力に含めない

## ワークフロー

### Step 1: プロジェクト構造の把握

以下のbashコマンドでプロジェクトの全体像を収集する:

```bash
# ディレクトリ構造
find <PROJECT_ROOT> -type f \
  -not -path '*/.git/*' -not -path '*/build/*' -not -path '*/target/*' \
  -not -path '*/node_modules/*' -not -path '*/.gradle/*' -not -path '*/.idea/*' \
  | head -500

# ソースファイル統計
find <PROJECT_ROOT> -name '*.java' | wc -l
find <PROJECT_ROOT> -name '*.kt' | wc -l

# 行数
find <PROJECT_ROOT> \( -name '*.java' -o -name '*.kt' \) -exec cat {} + | wc -l
```

### Step 2: ビルドシステムと依存関係の解析

**Gradle の場合:**
```bash
cat <PROJECT_ROOT>/build.gradle.kts 2>/dev/null || cat <PROJECT_ROOT>/build.gradle 2>/dev/null
cat <PROJECT_ROOT>/settings.gradle.kts 2>/dev/null || cat <PROJECT_ROOT>/settings.gradle 2>/dev/null
```

**Maven の場合:**
```bash
cat <PROJECT_ROOT>/pom.xml
```

ビルドファイルを読み、以下を抽出:
- Spring Boot バージョン
- Java/Kotlin バージョン
- 依存ライブラリ一覧
- マルチモジュール構成

### Step 3: ソースコード解析

#### 3a. エンドポイント抽出

```bash
# Controller クラスを特定
grep -rn '@RestController\|@Controller' <PROJECT_ROOT>/src --include='*.java' --include='*.kt' -l

# 各Controllerのマッピング一覧
grep -rn '@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping\|@RequestMapping' \
  <PROJECT_ROOT>/src --include='*.java' --include='*.kt'
```

検出した各Controllerファイルを `cat` で読み、以下を抽出:
- クラスレベルの `@RequestMapping` パス（ベースパス）
- 各メソッドの HTTP メソッド、パス、ハンドラメソッド名
- リクエスト/レスポンス型（判別可能な場合）

#### 3b. エンティティ抽出

```bash
# Entity クラスを特定
grep -rn '@Entity' <PROJECT_ROOT>/src --include='*.java' --include='*.kt' -l
```

検出した各Entityファイルを `cat` で読み、以下を抽出:
- クラス名、`@Table(name=...)` のテーブル名
- `@Column` フィールド名、型
- `@Id` 主キー
- `@OneToMany`, `@ManyToOne`, `@ManyToMany`, `@OneToOne` リレーション

#### 3c. Service/Component 抽出

```bash
# Service/Repository/Component を特定
grep -rn '@Service\|@Repository\|@Component' <PROJECT_ROOT>/src --include='*.java' --include='*.kt' -l
```

検出した各ファイルを `cat` で読み、以下を抽出:
- クラス名、ステレオタイプ
- コンストラクタインジェクション（依存先）
- publicメソッド一覧

#### 3d. 設定ファイル解析

```bash
find <PROJECT_ROOT>/src/main/resources -name 'application*' \
  \( -name '*.yml' -o -name '*.yaml' -o -name '*.properties' \)
```

各設定ファイルを `cat` で読み、以下を抽出（**パスワード等はマスク**）:
- プロファイル構成
- DB接続情報（URLのみ、認証情報はマスク）
- サーバーポート、コンテキストパス
- カスタム設定

#### 3e. 追加検出（該当する場合のみ）

```bash
# MyBatis マッパー
grep -rn '@Mapper' <PROJECT_ROOT>/src --include='*.java' --include='*.kt' -l
find <PROJECT_ROOT> -name '*Mapper.xml'

# Spring Security 設定
grep -rn 'WebSecurityConfigurerAdapter\|SecurityFilterChain\|@EnableWebSecurity' \
  <PROJECT_ROOT>/src --include='*.java' --include='*.kt' -l

# Spring Bean XML設定（レガシー）
find <PROJECT_ROOT> -name 'applicationContext*.xml' -o -name 'spring-*.xml'
```

### Step 4: ドキュメント生成

収集した情報から以下の5文書を Markdown で生成する。
テンプレートは `references/document_templates.md` を参照。
推測ルールは `references/inference_rules.md` を参照。

| # | ファイル | 内容 |
|---|---------|------|
| 1 | `01_system_overview.md` | システム概要 — 技術スタック、構成、統計 |
| 2 | `02_architecture_design.md` | アーキテクチャ設計 — レイヤー、コンポーネント図(Mermaid) |
| 3 | `03_api_spec.md` | API仕様 — エンドポイント一覧と詳細 |
| 4 | `04_database_design.md` | DB設計 — ER図(Mermaid)、テーブル定義 |
| 5 | `05_module_design.md` | モジュール設計 — Service/Repository構造、DI依存図(Mermaid) |

### Step 5: Mermaid 図の生成

ドキュメント内に以下の Mermaid 図を埋め込む:
- **コンポーネント図**: Controller → Service → Repository の依存
- **ER図**: Entity間リレーション、フィールド、PK/FK
- **依存注入グラフ**: Service間のDI構造（循環依存があれば警告）

### Step 6: 出力

全ドキュメントを指定ディレクトリに出力。
デフォルト: `<PROJECT_ROOT>/docs/generated/`

> **要件定義書について**: 要件定義書はコードからの推測では不十分なため、
> 別スキル `requirements-interview` で対話的に生成する。
> 本スキルの出力を先に生成した上で、そちらを実行すること。

## 対応しないケース・手動補完が必要なケース

- **XML定義のBean**: `applicationContext.xml` 等のDI定義 — ファイルを直接読んで補完
- **MyBatis**: `@Mapper` + XMLマッピングファイル — Entity解析とは別に読む
- **Spring WebFlux**: `RouterFunction`ベースのルーティング — grep パターンが異なる
- **動的ルーティング**: プログラマティックなルート登録

検出した場合は該当ファイルを直接読んで情報を補完すること。
