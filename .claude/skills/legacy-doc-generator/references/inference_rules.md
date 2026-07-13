# 推測ルールと判断基準

解析結果からドキュメントを生成する際の推測ルールを定義する。

## 事実 vs 推測の分類基準

### 事実（Fact）として扱えるもの
- ソースコード上のクラス名、メソッド名、フィールド名
- アノテーションから確定するHTTPメソッド、パス
- build.gradle / pom.xml に記載された依存ライブラリとバージョン
- application.yml / properties の設定値
- JPA Entity のフィールドとリレーション定義
- ディレクトリ構造、ファイル数、行数

### 推測（Inference）として明示が必要なもの
- ビジネス要件、ユースケース
- 非機能要件（性能、可用性など）
- 命名規則から推測される業務ドメインの意味
- CRUD操作パターンから推測される画面・機能
- 認証・認可の詳細フロー
- 外部システム連携の詳細

## アーキテクチャパターン検出ルール

パッケージ構成から以下を検出:

| パッケージパターン | 推測アーキテクチャ |
|---|---|
| controller/service/repository | レイヤードアーキテクチャ |
| adapter/port/usecase/domain | ヘキサゴナル/クリーンアーキテクチャ |
| api/domain/infrastructure | オニオンアーキテクチャ |
| web/business/data | 3層アーキテクチャ |
| 機能名ごとのパッケージ分割 | パッケージ by Feature |

## 依存ライブラリから推測される技術要素

| ライブラリ含有キーワード | 推測 |
|---|---|
| spring-security | 認証・認可機能あり |
| spring-data-jpa, hibernate | JPA/ORM使用 |
| mybatis | MyBatis使用（JPAと異なる） |
| flyway, liquibase | DBマイグレーション管理あり |
| spring-cloud | マイクロサービス構成の可能性 |
| spring-kafka, spring-amqp | メッセージキュー連携 |
| spring-batch | バッチ処理あり |
| springdoc, swagger | API文書自動生成設定あり |
| spring-mail | メール送信機能あり |
| spring-cache, redis | キャッシュ機構あり |
| thymeleaf, freemarker | サーバーサイドレンダリングあり |
| spring-webflux | リアクティブ対応 |

## Mermaid図の生成ルール

### コンポーネント図
- Controller → Service → Repository の依存を描画
- 外部連携が推測されるServiceは外部システムノードを追加

### ER図
- Entity間のリレーションを描画
- フィールド名から型を表記
- PK/FK を明示

### 依存注入グラフ
- Service/Componentの`injected_dependencies`から有向グラフを生成
- 循環依存があれば警告として出力
