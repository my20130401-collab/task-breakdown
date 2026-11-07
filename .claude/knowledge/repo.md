# リポジトリ・環境の知見

- コマンドはすべて `docker compose run --rm web ...` で実行する。ホストの Ruby で `bin/rails` を叩くと DB に繋がらない
- Tailwind の watch はコンテナ内で `poll` モード（`tailwindcss:watch[always,poll]`）。macOS のボリューム越しではファイル変更イベントが届かないため
- CSS が反映されないときは `docker compose run --rm css bin/rails tailwindcss:build` で手動ビルド
- ルーティング（`config/routes.rb`）: `resource :session`（`/session/new`）・`resource :registration`（`/registration/new`）・`/terms` `/privacy`（`PagesController`、ログイン不要）・`root "tasks#new"`・`resources :tasks`（`id` は数値のみ。`POST /tasks/:id/redecompose`）・`tasks/:task_id/subtasks`（`Tasks::SubtasksController`、`PATCH .../toggle_status`）・`/up`。画面モック（`MocksController`、`/tasks/sample` `/login` `/signup`）は #107 で撤去済みで、`spec/requests/removed_mock_routes_spec.rb` が 404 を確認する
- 認証は Rails 8 標準（`Authentication` concern）。ログイン不要の画面は `allow_unauthenticated_access`、ログイン済みで開かせない画面は `redirect_if_authenticated`。他人のデータは `Current.user.tasks.find` で 404 にする
- AI 分解: `TasksController#create` / `#redecompose` が分解履歴（`pending`）を作って `DecomposeTaskJob` を積む。ジョブは `TaskDecomposer` → `Llm::Client.build`（`LLM_CLIENT` → `OPENAI_API_KEY` の有無で `openai` / `fake`）を呼び、結果を `turbo_stream_from @task` に `decomposition_content_<id>` / `decomposition_status_<id>` / `task_progress_<id>` の 3 か所へ配信する
- `compose.yaml` に `env_file` は置かない（`.env` はコンテナに渡らない）。`.env` を渡すとテストコンテナにも `OPENAI_API_KEY` が入り、`Llm::Client.build` が openai を選んで WebMock 遮断で AI 関連の spec が落ちる（CI は `.env` が無いので気づけない）。開発サーバ・テストは fake、実 API は `docker compose run --rm -e OPENAI_API_KEY web bin/rails eval:decompose` のようにコマンド単位で渡す（#111）
- SimpleCov の閾値は `MIN_COVERAGE`（既定 0）。カバレッジは目標 80% の参考値で、CI で閾値チェックはしない（キックオフの方針）

## デザイントークン（`app/assets/tailwind/application.css` の `@theme`）
- ビューに `#xxxxxx` / `rgba(` / `text-[9px]` を書かない（`grep -rnE '#[0-9a-fA-F]{6}|rgba\(|text-\[9px\]' app/views` が 0 件であること）。`@theme` に足した値は `bg-<name>` `text-<name>` `shadow-<name>` 等で使える
- 色: `ink` `muted` `subtle` `canvas` `line` `line-strong`（完了チェックの丸枠）`line-dashed`（「タスクを追加」の破線）`brand` `brand-hover` `brand-soft` `brand-dot` `accent` `accent-soft` `danger`（失敗・削除の文字）`danger-dot`（失敗の点）`danger-soft`（エラー背景。未使用）`avatar`
- 影: `shadow-card`（カードのホバー）`shadow-float`（フォームカード）。文字: `text-2xs`（10px。最小サイズ）
- Tailwind v4 は使われたトークンだけ CSS に出す（未使用の `danger-soft` はビルド結果に出ない）。ビルドは圧縮され `rgba(32,36,33,0.18)` → `#2024212e`、`0.213` → `.213` になる
- `spec/assets/design_tokens_spec.rb` がビルド後の CSS（`app/assets/builds/tailwind.css`）を読んで値を検査する。事前に `docker compose run --rm css bin/rails tailwindcss:build` が必要（css コンテナが watch 中なら最新）
- フォーカス表示はビューにクラスを書かず、`@layer base` の `:where(a[href], button, [role=tab], [role=menuitem], [contenteditable=true]):focus-visible` で `ring-2 ring-brand-dot` を一括適用している（`brand-soft` は白地でコントラスト約 1.1:1 で見えないため使わない。入力欄の `focus:ring-brand-soft` は枠線 `border-brand` と併用なので別扱い）
- `<head>` は `layouts/_head.html.erb` に集約（両レイアウトが render）。画面タイトルは `content_for :title`、追加タグは `content_for :head`

## 画面の実装メモ
- S-5 の行は `<li>` がカード（`px-5 py-5 gap-4 rounded-xl`、ホバーで `shadow-card`）。中は `<a>`（期限・タイトル・進捗）と行メニュー（`_menu`、`id` は `parent-task-menu-01`… の通し番号、`label` は「『親タスク名』のメニュー」）の兄弟。リンクの中にボタンを入れない。行の期限表示は `data-row-due`
- S-5 の行のフォーカス: `<li>` に `has-[>a:focus-visible]:ring-2 ring-brand-dot`、リンク側は `focus-visible:ring-0`（カード全体を囲み、メニューへのフォーカスでは囲まない。`focus-within` だとメニューでも囲んでしまう）
- S-5 の行は stretched link: `<li>` が `relative`、`<a>` の `after:absolute after:inset-0` でカード全面を当たり判定にする。メニュー（`_menu` のルートは `relative`）は DOM 上でリンクより後ろなので z-index 無しで前面に出る。行メニューに `z-10` 等を付けると、開いたドロップダウンが次の行のメニューの下に潜るので付けない
- S-5 の親行 `<li>` と S-4 のサブタスク `<li>` は `data-done` を持つ（完了フィルタの対象）。S-5 の日付 `<section>` は `data-completed-filter-target="group"`
- S-4 のサブタスク操作（追加・編集・削除・完了・日付タブ）は Turbo Stream。追加・編集・削除後は `subtasks_area` ごと描き直し（期限順に並べ直す）、完了は該当カードだけ差し替え、いずれも `task_progress_<id>` を差し替える。日付タブはサーバ側で絞り込む（`filter=all|today|tomorrow|YYYY-MM-DD`）
- 期限の表示はすべて `DueDateHelper`（`due_label` / `due_key` / `due_time_tag`）を通す。期限は `<time datetime>` で出力され、spec はこれを拾って書式を検査する
- 日付に依存する spec は `travel_to` で固定する（`ActiveSupport::Testing::TimeHelpers` は `rails_helper` で全 spec に include 済み）
- 既知のずれ: サイドバーの `children` 判定が `%w[task_detail]`（モック時代のアクション名）のままで、S-4（`tasks#show`）でマイタスクがハイライトされない（#111 で docs は現状に合わせた）

## system spec（`spec/system/`）
- JS を動かす spec は `:js` を付ける（`type: :system` は配置から推論）。ドライバは cuprite（`spec/support/capybara.rb` の `:cuprite_ja`、1280x900・ja-JP）。`:js` なしは rack_test
- ローカル: `docker compose run --rm web bundle exec rspec spec/system`。Chromium は `Dockerfile.dev` に入っており `BROWSER_PATH=/usr/bin/chromium`。イメージが古ければ `docker compose build web`
- 画面を見ながらデバッグしたいときはホストで動かせないので、`page.save_screenshot("x.png")` で画像を残して確認する。相対パスは `Capybara.save_path`（`tmp/capybara/`）基準になる（`"tmp/screenshots/x.png"` と書くと `tmp/capybara/tmp/screenshots/` に出る）
- cuprite の `click` / `hover` は対象を画面中央付近へスクロールしてから操作する。sticky なサイドバー下部の要素をクリックすると `window.scrollY` が変わり、スクリーンショットの見た目がずれる（アプリの挙動ではない）。見た目を撮るときは `execute_script("...click()")` で押す
- 失敗時のスクリーンショットは `tmp/screenshots/` に保存される
- cuprite は `url_blacklist` で Web フォント（fonts.googleapis.com / fonts.gstatic.com）を遮断している（外部の応答待ちによる Ferrum タイムアウト対策）。system spec ではフォントが当たらない（Docker の Chromium は和文セリフ体が豆腐になる）が、見た目の確認用スクリーンショットでもそのまま
- 遮断したリクエストは `page.driver.network_traffic` に残らない（`blocked?` で探せない）。遮断の確認は「該当 URL が 1 件も無い」で書く

## 横断検査（`spec/requests/pages_*_spec.rb`）
- 巡回する URL は `spec/support/pages.rb` の `Pages::PATHS`。現在はログイン前の画面（`/session/new` `/registration/new` `/terms` `/privacy`）。**画面や状態を足したらここにも足す**（ログイン後の画面への拡張は #109）。`Pages` は request spec に include 済み
- `pages_links_spec`: 全 `<a href>` / `<form action>` が `recognize_path` で解決できる（`#`・外部 URL 不可。`data-turbo-method` / hidden `_method` も見る。外部参照は `ALLOWED_EXTERNAL_HOSTS` の Web フォントだけ）。ログイン前レイアウト（`aside` 無し・ロゴは `/`）、S-1/S-2 の POST 先、規約リンクの `target=_blank rel=noopener` もここ
- `pages_buttons_spec`: 全 `<button>` が「`type="submit"` かつ form 内」か「`data-action` あり」のどちらかで、`type` を明示。見た目だけのボタン（`data-mock="noop"`）は全画面で 0 件（`shared/_menu` の href 無し項目が出たら落ちる）。規約・ポリシーにはボタンが無いので、空集合の検査は巡回全体の `<button>` 件数 > 0 で行う
- `pages_views_spec`: `<title>` が「〜 | Tasklet」、トークン外の色・文字サイズ（描画結果と `app/views` の両方）、id の画面内一意（`role="menu"` 含む）、メニューのトリガーと完了チェック（`data-subtask-card-target="check"`）の `aria-label` の一意、`contenteditable` が無い
- 検査は `pages_document`（`<template>` を取り除いた Nokogiri 文書）で読む。違反の報告名は `element_name`（`aria-label` → 文字列 → `id`）
- 対象要素が空なら失敗させる（`pages_links_spec` は `a, form` が 0 件なら落ちる。空集合で素通りさせない）

## 作業ディレクトリの共有
- 複数のエージェント（developer / tester 等）が同じ作業ディレクトリを使う。tester が比較のために `git switch main` や特定コミットを checkout すると、developer 側が detached HEAD になり push が漏れる。別リビジョンとの比較は `git worktree add ../tb-main origin/main` など別ディレクトリで行う（#12, 2026-10-25）

## 共通部品と規約
- **非表示**: 完了フィルタで隠す要素は `data-hidden-by-done` 属性で表し、`application.css` のレイヤー外ルール（`display: none`）で消す。`hidden` 属性やクラスの付け外しで隠さない（メニュー本体と空状態の表示切替だけは `hidden` 属性）
- **削除の確認**: 削除のメニュー項目は `method: :delete` と `data: { turbo_confirm: "本当に削除しますか？" }`、`danger: true`（赤字）
- `shared/_decomposition_status`（`status: :decomposing | :done | :failed`。ルートに `data-decomposition-status`）: S-4 見出し上。ジョブからも同じ partial を配信する。未知の値は例外
- `shared/_menu`（`id:` `items: [{ label:, href:, method:, data:, danger: }]` `placement: :down | :up` `label:`）＋ `menu_controller.js`: `href` 付き項目は `<a role="menuitem">`（`method` は `data-turbo-method` になる）。開閉状態はトリガーの `aria-expanded` とメニューの `hidden`。外側クリック・Esc（トリガーへフォーカスを戻す）・Tab でメニュー外へ出たときに閉じ、↑↓/Home/End で項目移動。`id` は画面内で一意にする（サイドバーは `user-menu`、S-4 は `task-menu` / `subtask-menu-<id>`）。一覧で繰り返すときはトリガーの `label:` を「『対象名』のメニュー」にする
- `shared/_content_header`（S-4・S-5 のヘッダー。左はブロックで渡す）＋ `completed_filter_controller.js`: 両画面とも `<header>` と本文を `data-controller="completed-filter"` のラッパーで包む。状態はトグルの `aria-pressed` だけ。ラッパー内の `[data-done]` を対象に、`data-done="true"` へ `data-hidden-by-done` を付け外しする。`MutationObserver` で `data-done` の変化と要素の追加（Turbo Stream の差し替え）に追随する。`data-completed-filter-target="empty"` の要素は「`[data-done]` の全件が `data-hidden-by-done`」のときだけ `hidden` を外す（＝全完了の空状態）。`[data-done]` が 1 件も無い画面では出さない。`group` ターゲットは中の `[data-done]` がすべて隠れたら見出しごと隠す
- `shared/_empty_state`（`icon:` `title:` `body:` `action: { label:, href: }` `data:` `hidden:`）、`shared/_task_progress`（`done:` `total:`。`total` 0 は「—」でバーは `hidden`。バー幅は 100% を上限に丸める。ルートに `data-task-progress`、`total` > 0 なら `role="progressbar"` と `aria-valuenow/max`）。S-4 は `tasks/_progress`（`id="task_progress_<id>"`）で包んで差し替える
- `shared/_legal_page`（`title:` `eyebrow:` `sections: [{ heading:, body: [...] }]`。`body` の文字列は段落、配列は箇条書き）: S-6・S-7 の本文は `app/views/pages/` に節単位で書き、`docs/screens.md` の S-6/S-7 の節構成表と一致させる。節を足したら `spec/requests/pages_spec.rb` の文言検査も直す
- S-3 の「200 文字まで」は `#title-hint`（textarea の `aria-describedby`）。S-2 の「（いずれも新しいタブで開きます）」は `#terms-new-tab`（規約リンク 2 本の `aria-describedby`）。チェックボックスの label には入れない（label の名前が変わり `check "利用規約とプライバシーポリシーに同意する"` が壊れる）
- S-3 の期限の `min` はサーバの現在時刻（分単位、`include_seconds: false`）。空白だけの入力は `prompt_controller#validate` が `setCustomValidity` で止める（入力例チップは値を入れた後に `input` イベントを dispatch して再検証させる）
- 部品の単体検査は `spec/views/shared/`（view spec）
- system spec で `minlength` を検証するときは `send_keys` で打ち込む（`fill_in` の値設定はユーザー編集扱いにならず `tooShort` が立たない）
