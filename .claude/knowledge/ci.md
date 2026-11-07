# CI の知見

- GitHub Actions（`.github/workflows/ci.yml`）: brakeman / bundler-audit / importmap audit / rubocop / rspec
- rspec ジョブは PostgreSQL サービスコンテナを使う。DB 接続は `DB_HOST` 等の環境変数（`config/database.yml`）
- test ジョブは `tailwindcss:build` → `db:prepare` → rspec の順。`spec/assets/design_tokens_spec.rb` はビルド後 CSS を読むので、ビルド手順を消すと落ちる
- 横断検査（`spec/requests/pages_*_spec.rb`）が落ちたら、失敗メッセージに違反した要素のラベルが出る。新しいリンク・ボタンの規約違反か、`Pages::PUBLIC_PATHS` / `Pages::AUTHENTICATED_PAGES` の追加漏れかを見る（失敗メッセージの巡回名で画面と状態が分かる）
- system spec（`:js`）はランナーに入っている Google Chrome を `BROWSER_PATH` で cuprite に渡して実行する（「Locate Chrome for system specs」ステップ）

## 落ちたときの見方
- まず失敗したジョブとステップを特定する: `gh run view <run-id> --log-failed`（run-id は `gh run list --branch <ブランチ>`）
- lint: `docker compose run --rm web bin/rubocop -a` で自動修正し、残りを手で直す
- rspec（request / helper）: ローカルで同じ spec を `docker compose run --rm web bundle exec rspec <path>` で再現する。日付依存の失敗は `travel_to` 漏れを疑う（CI は UTC、アプリは `Asia/Tokyo`）
- rspec（system）: 失敗時は artifact `screenshots` に画面のスクリーンショットが上がる（`gh run download <run-id> -n screenshots`）。`Ferrum::BinaryNotFoundError` は Chrome が見つからない（「Locate Chrome」ステップの出力を確認）、`Ferrum::TimeoutError` / `ProcessTimeoutError` は起動の遅さなので `process_timeout` を見直す
- デザイントークン spec: 「tailwind.css がありません」はビルド漏れ。値の不一致はトークンの値を変えたか、Tailwind の更新で圧縮後の表記が変わったかのどちらか

## flaky
- system spec が Google Fonts（fonts.googleapis.com / gstatic）のリクエスト保留で Ferrum タイムアウトすることがあった（`smoke_spec`、#17 の CI、再実行で緑）。#11 で cuprite の `url_blacklist` により遮断済み（`spec/support/capybara.rb`、確認は `smoke_spec`）。それでも Ferrum タイムアウトが出たら、他の外部リクエストが増えていないか `pages_links_spec` の外部参照の検査と合わせて見る。一時しのぎは `gh run rerun <id> --failed`（2026-10-25）

