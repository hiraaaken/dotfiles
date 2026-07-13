---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(date:*)
argument-hint: [output-dir]
description: その日の全コミットから作業ログを生成しコミットする
---

今日の作業内容をログとして記録し、コミットします。

## 手順

1. `git log --since="00:00" --oneline` で今日のコミット一覧を取得
2. `git log --since="00:00" -p` で今日の全差分を確認
3. 未コミットの変更があれば `git status` と `git diff HEAD` で確認
4. 以下のフォーマットでログファイルを作成
5. ログファイルをコミット

出力先: $ARGUMENTS（指定がなければ `~/de
/logs/`）
ファイル名: 今日の日付 `yyyymmdd.md`

## 出力フォーマット
```md
# {yyyy-mm-dd} 作業ログ

## 今日のコミット
- コミットハッシュとメッセージの一覧

## 変更ファイル一覧

## 作業内容
- 何を実装・修正したか

## 得られた知見
- 学んだこと、ハマった点と解決策

## 次回への申し送り
- 残タスク、注意点
```

## 最後に実行すること

1. 未コミットの変更があれば先にコミットするか確認
2. ログファイルを作成
3. `git add <ログファイル>`
4. `git commit -m "docs: add daily log {yyyymmdd}"`

コミット前にユーザーの承認を求めてください。
