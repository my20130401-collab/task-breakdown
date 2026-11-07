# Tasklet（AI タスク分解アプリ）

新入社員が入力した大分類タスクを、AI がベテランのように実行可能なサブタスクへ分解する Rails アプリ。
会員登録・ログイン（Rails 8 標準の認証）、タスクの作成、AI 分解（Active Job ＋ Turbo Stream で非同期に画面へ反映）、サブタスクの追加・編集・削除・完了まで本実装済み。画面モック（`MocksController`）は撤去済み（#107）。

## 最初に読むもの
- 仕様: `docs/README.md`（キックオフ・要件・画面・データ・AI 設計）
- 蓄積された知見: `.claude/knowledge/INDEX.md`

@.claude/knowledge/INDEX.md

## コマンド（すべて Docker Compose 経由で実行する）
| 用途 | コマンド |
|---|---|
| 起動 | `docker compose up -d` → http://localhost:3000 |
| DB 準備 | `docker compose run --rm web bin/rails db:prepare` |
| テスト | `docker compose run --rm web bundle exec rspec` |
| 単体ファイル | `docker compose run --rm web bundle exec rspec spec/path/to_spec.rb` |
| Lint | `docker compose run --rm web bin/rubocop`（自動修正は `-a`） |
| セキュリティ | `docker compose run --rm web bin/brakeman -q --no-pager` |
| CSS ビルド | `docker compose run --rm css bin/rails tailwindcss:build` |
| ログ | `docker compose logs -f web` |

ホストの Ruby で `bin/rails` 等を直接実行しない（DB はコンテナ内の PostgreSQL）。

## 構成
- Rails 8.1 / Ruby 3.4 / PostgreSQL 17 / Hotwire（Turbo・Stimulus）/ Tailwind CSS v4 / importmap
- デザイントークン（色・フォント）は `app/assets/tailwind/application.css` の `@theme`。色は `bg-brand` `text-muted` `border-line` 等のトークン名を使い、16 進数を直接書かない
- アイコンは `app/views/shared/_icon.html.erb`（インライン SVG）。新しいアイコンはここに追加する
- AI 呼び出しは `app/services/llm/` に閉じ込め、テストでは固定応答クライアントに差し替える（設計: `docs/ai-decomposition.md`）

## 開発ルール
- 開発フロー（詳細は `docs/kickoff.md` (6)）: エピックは `main` から `epic/<番号>-<説明>` を切り、子 Issue ごとに epic から `feature/<番号>-<説明>` を切る。子 PR → epic は CI green で Squash merge（レビュー不要）、epic → `main` はレビュー承認 1 名で Merge commit
- 受入条件 → spec（Red）→ 実装（Green）→ リファクタの順で進める
- 外部通信は WebMock で遮断済み。実 API を叩くテストを書かない
- コミット: `<feat|fix|refactor|test|docs|chore>: <要約>`
- 仕様と実装がずれたら、実装と同じ PR で `docs/` を更新する

## ドキュメントの書き分け
- `docs/` と `README.md` は運用者・関係者にも渡る前提。Issue/PR 番号・ブランチ名・開発経緯を書かない
- 開発の経緯や Issue 参照は PR 本文・コミットメッセージ・`.claude/knowledge/` に書く
