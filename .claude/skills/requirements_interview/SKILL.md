---
name: requirements-interview
description: >
  Generate requirements specification documents through interactive interview sessions.
  No external runtime required. Works as a companion to the legacy-doc-generator skill:
  first run legacy-doc-generator to produce design docs, then run this skill to
  interactively build a requirements spec by asking the user to confirm or deny
  code-inferred requirements. Triggers when user asks to: create requirements spec,
  generate requirements definition, build requirements document, run requirements
  interview, define system requirements interactively. Japanese triggers:
  要件定義書を作成、要件定義インタビュー、要件をヒアリング、要件を定義。
  Prerequisites: generated docs from legacy-doc-generator or access to project source.
---

# Requirements Interview Skill

コードベースの解析結果を元に推測した要件候補を提示し、
対話的に確認・修正しながら要件定義書を生成するスキル。
**外部ランタイム不要。**

## 前提条件

`legacy-doc-generator` で生成した設計書群、またはプロジェクトソースへの直接アクセスが必要。
なければ先に `legacy-doc-generator` を実行するよう案内する。

## ワークフロー

### Step 1: 情報の収集

`legacy-doc-generator` が生成した設計書を読み込む:
```bash
cat <DOCS_DIR>/01_system_overview.md
cat <DOCS_DIR>/03_api_spec.md
cat <DOCS_DIR>/04_database_design.md
cat <DOCS_DIR>/05_module_design.md
```

設計書がない場合はプロジェクトソースから直接収集する（legacy-doc-generator の Step 1〜3 を参照）。

### Step 2: 要件の推測

設計書またはソースから以下のカテゴリで要件候補を推測する。
推測ルールは `references/inference_rules.md` を参照。

**推測カテゴリと根拠:**

| カテゴリ | 推測の根拠 |
|---------|-----------|
| 機能要件（CRUD） | APIエンドポイントのHTTPメソッドとリソース名 |
| 機能要件（ビジネスロジック） | Service層のCRUD以外のメソッド |
| データ要件 | Entity定義、リレーション |
| セキュリティ要件 | spring-security依存、SecurityConfig |
| 非機能要件（性能） | コードからは推測不可 → 常に質問 |
| 非機能要件（運用） | プロファイル構成、Flyway/Liquibase依存 |
| 外部連携要件 | Kafka/RabbitMQ/Mail等の依存 |
| ビジネス背景 | コードからは推測不可 → 常に質問 |

### Step 3: インタビュー進行

`references/interview_guide.md` の進行ルールに厳密に従う。

**フェーズ構成:**

1. **Phase 0: オープニング** — 解析結果サマリの提示、ユーザーの役割確認、所要時間の目安
2. **Phase 1: ビジネス背景** — コードから分からない最重要情報を最初に聞く
3. **Phase 2: 機能要件** — confidence: high から順に確認。CRUDはまとめて、ビジネスロジックは個別に
4. **Phase 3: データ要件** — ER図を提示しながら確認。カスケード動作は必ず聞く
5. **Phase 4: セキュリティ・非機能要件** — 「不明でOK」と明示
6. **Phase 5: 外部連携** — 依存から推測した連携先を提示、未検出の連携も質問
7. **Phase 6: クロージング** — 未確認事項一覧、ドラフト生成、レビュー

**進行ルール:**
- 一度に聞く質問は**最大3つ**
- 「不明」は有効な回答。無理に聞かない
- 回答に基づいて深掘り。機械的に全問聞かない
- 進捗を示す（「全X問中Y問目」等）
- ユーザーが「もう十分」と言えばクロージングに移行

### Step 4: 回答の記録

各質問の回答を以下の状態で管理:
- ✅ **confirmed** — ユーザーが明確に回答
- ❌ **denied** — 推測が誤りだった
- 🔄 **modified** — 推測を修正して確認
- ❓ **unknown** — ユーザーが「不明」と回答
- ⚠️ **unconfirmed** — 未確認の推測

### Step 5: 要件定義書の生成

`references/output_template.md` のテンプレートに従い Markdown で出力。
出力先: `<PROJECT_ROOT>/docs/generated/requirements_spec.md`

### Step 6: レビューと修正

生成した要件定義書をユーザーに提示し、修正を受け付ける。
修正を反映して最終版を出力。

## 注意事項

- 全質問を全て聞く必要はない。ユーザーの時間を尊重する
- セキュリティの具体的な設定値は要件定義書に含めない
- インタビューログ（質問と回答の全記録）を付録として添付
