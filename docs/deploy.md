# 運用手順書（デプロイ・本番環境に関する仕様）

## 1. デプロイフロー
- GitHubの `main` にコードがマージされると、Renderの自動デプロイがトリガーされる。
- アプリケーション起動時のエントリーポイント（`bin/docker-entrypoint`）にて、自動的に `db:prepare` が実行され、データベースの作成・マイグレーションが行われる。
- デプロイの状況やログは、Renderのダッシュボード（Events/Logs）から確認可能。

## 2. 環境変数一覧
本番環境（Render）の Environment ページにて以下の変数を設定・管理する。
- `RAILS_MASTER_KEY`: 認証情報の復号に使用（`config/master.key` の値）
- `DATABASE_URL`: Neonのデータベース接続URL（プーラー経由）
- `DATABASE_MIGRATION_URL`: Neonのマイグレーション用直接接続URL
- `RAILS_ENV`: `production`（本番環境の指定）
- `WEB_CONCURRENCY`: Pumaのワーカープロセス数（メモリ節約のため基本は `1` とする）
- `SOLID_QUEUE_IN_PUMA`: `true`（Render無料枠にはバックグラウンドワーカーがないため、Pumaのプロセス内でSolid Queueを起動させる）
*(※ `OPENAI_API_KEY` 等の追加変数は、今後の機能実装フェーズに応じて設定する)*

## 3. インフラ構成・設定の前提
- **データベース（Neon）の接続と管理:** アプリからの通常稼働時の接続はプーラーを経由し（`DATABASE_URL`）、マイグレーション実行時（`db:prepare`）のみエントリーポイントで直接接続（`DATABASE_MIGRATION_URL`）に差し替える。また、Solid QueueやSolid Cableのテーブル管理は別DB扱いせず、すべてメインのDB（primary）に一本化して管理している。
- **メモリ制限（Render）:** 無料枠のメモリ512MB制限に収めるため、Pumaは「1プロセス・3スレッド」の設定とし、jemallocを利用してメモリ効率を上げている。

## 4. 本番環境（無料枠）の制限に関する注意点

### Renderのコールドスタートについて（※仕様のため設定不要）
- Renderの無料プラン（Free Instance）は、アプリに対して15分間アクセスのない状態が続くと自動的にスリープ状態（スピンダウン）になる。
- スリープ状態から復帰する最初のアクセス時には「コールドスタート」が発生し、**画面が表示されるまでに約1分程度の待ち時間**が発生するため、エラーと勘違いしないよう注意すること。

### Neonの100 CU時間/月制限とポーリング間隔の影響について
- Neonの無料プランには「1ヶ月あたり 100 Compute Hours (CU)」の計算時間制限（0.25 CU固定）がある。
- **対策（設定済み）:** Solid QueueやSolid Cableが短い間隔でDBにポーリングを行うと、Neonがスリープできず月間100 CUを使い切ってしまうため、無アクセス時のCU消費を抑える目的で**DBポーリング間隔を5秒に設定**している（`config/cable.yml` は `5.seconds`、`config/queue.yml` は `5` と指定）。
