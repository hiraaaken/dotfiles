# ドキュメント生成テンプレート

解析結果JSONを元に、以下のドキュメントを生成する。
**重要**: 各セクションで「事実（コードから確認可能）」と「推測（コードから推測）」を明確に分離すること。

## 出力ファイル一覧

| ファイル名 | 内容 | 粒度 |
|---|---|---|
| `01_system_overview.md` | システム概要書 | 概要 |
| `02_architecture_design.md` | アーキテクチャ設計書 | 設計 |
| `03_api_spec.md` | API仕様書 | 設計 |
| `04_database_design.md` | データベース設計書 | 設計 |
| `05_module_design.md` | モジュール設計書 | 設計 |

---

## 01: システム概要書テンプレート

```markdown
# システム概要書: {project_name}

> **自動生成日**: {date}
> **生成元**: コードベース静的解析による自動生成
> **注意**: 本文書はソースコードの静的解析結果に基づく自動生成文書です。ビジネス要件や運用情報など、コードに現れない情報は含まれません。

## 1. システム識別情報

| 項目 | 値 |
|---|---|
| プロジェクト名 | {project_name} |
| 言語 | {language} |
| フレームワーク | Spring Boot {spring_boot_version} |
| Java/Kotlinバージョン | {java_version} / {kotlin_version} |
| ビルドシステム | {build_system} |
| モジュール数 | {module_count} |

## 2. 技術スタック

### 2.1 主要依存ライブラリ
{dependencies_table}

### 2.2 ソースコード統計
{source_stats_table}

## 3. システム構成概要

### 3.1 ディレクトリ構成
{directory_tree}

### 3.2 パッケージ構成
{package_structure}

### 3.3 モジュール構成（マルチモジュールの場合）
{modules_list}

## 4. 解析時の警告事項
{warnings}
```

---

## 02: 要件定義書テンプレート

```markdown
# 要件定義書（推測）: {project_name}

> ⚠️ **本文書の性質について**
> 本文書はソースコードの静的解析から**推測**された要件です。
> 実際のビジネス要件とは乖離している可能性があります。
> 「事実」マークが付いた項目のみがコードから直接確認可能な情報です。

## 1. 機能要件（推測）

### 1.1 API機能一覧から推測される機能
<!-- endpoints一覧からCRUD操作を分析し、リソースごとに機能を推測 -->
{inferred_features}

### 1.2 データモデルから推測されるドメイン
<!-- entities一覧からドメインモデルを推測 -->
{inferred_domains}

### 1.3 サービス層から推測されるビジネスロジック
<!-- services一覧からビジネスルールを推測 -->
{inferred_business_logic}

## 2. 非機能要件（推測）

### 2.1 データベース
- 【事実】使用DB: {datasource_info}
- 【推測】データ量想定: (エンティティ構造から推測)

### 2.2 認証・認可
- 【事実】Spring Security依存: {has_spring_security}
- 【推測】認証方式: (依存ライブラリから推測)

### 2.3 外部連携
- 【推測】(依存ライブラリから推測される外部連携先)

## 3. 確認が必要な項目
<!-- コードだけでは判断できない要件をリストアップ -->
{confirmation_needed}
```

---

## 03: アーキテクチャ設計書テンプレート

```markdown
# アーキテクチャ設計書: {project_name}

## 1. アーキテクチャ概要

### 1.1 レイヤー構成
<!-- パッケージ構成からレイヤーを特定 -->
{layer_analysis}

### 1.2 アーキテクチャパターン
- 【事実】パッケージ構成から検出されたパターン: {detected_patterns}
- 【推測】採用アーキテクチャ: (レイヤー/クリーンアーキテクチャ等)

### 1.3 コンポーネント図（Mermaid）
```mermaid
{component_diagram}
```

## 2. モジュール間依存関係

### 2.1 依存関係図（Mermaid）
```mermaid
{dependency_diagram}
```

### 2.2 依存関係マトリクス
{dependency_matrix}

## 3. 設定・環境構成
### 3.1 プロファイル構成
{profiles}

### 3.2 環境変数・設定値
{config_highlights}
```

---

## 04: API仕様書テンプレート

```markdown
# API仕様書: {project_name}

## エンドポイント一覧

| # | Method | Path | Controller | Handler | ファイル |
|---|--------|------|-----------|---------|---------|
{endpoints_table}

## エンドポイント詳細

<!-- 各エンドポイントの詳細（パラメータ、レスポンス型が検出できた場合） -->
{endpoint_details}
```

---

## 05: データベース設計書テンプレート

```markdown
# データベース設計書: {project_name}

## 1. ER図（Mermaid）
```mermaid
erDiagram
{er_diagram}
```

## 2. テーブル定義

<!-- 各エンティティからテーブル定義を生成 -->
{table_definitions}

## 3. リレーション一覧
{relationships_table}
```

---

## 06: モジュール設計書テンプレート

```markdown
# モジュール設計書: {project_name}

## 1. Service一覧

| # | Service名 | 依存先 | メソッド数 | ファイル |
|---|----------|-------|----------|---------|
{services_table}

## 2. Service詳細

<!-- 各Serviceのメソッド一覧と依存関係 -->
{service_details}

## 3. Repository一覧
{repositories}

## 4. 依存注入グラフ（Mermaid）
```mermaid
{injection_graph}
```
```
