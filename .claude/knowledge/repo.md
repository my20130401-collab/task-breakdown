# リポジトリ・環境の知見

- コマンドはすべて `docker compose run --rm web ...` で実行する。ホストの Ruby で `bin/rails` を叩くと DB に繋がらない
- Tailwind の watch はコンテナ内で `poll` モード（`tailwindcss:watch[always,poll]`）。macOS のボリューム越しではファイル変更イベントが届かないため
- CSS が反映されないときは `docker compose run --rm css bin/rails tailwindcss:build` で手動ビルド
- 画面モック段階: ルーティングは `MocksController`（`/` `/tasks` `/tasks/sample` `/signup` `/login` `/terms` `/privacy`、POST `/signup` `/login`）。本実装時は `docs/screens.md` の「URL（実装予定）」に置き換え、モックは削除する
- SimpleCov の閾値は `MIN_COVERAGE`（既定 0）。カバレッジは目標 80% の参考値で、CI で閾値チェックはしない（キックオフの方針）

## デザイントークン（`app/assets/tailwind/application.css` の `@theme`）
- ビューに `#xxxxxx` / `rgba(` / `text-[9px]` を書かない（`grep -rnE '#[0-9a-fA-F]{6}|rgba\(|text-\[9px\]' app/views` が 0 件であること）。`@theme` に足した値は `bg-<name>` `text-<name>` `shadow-<name>` 等で使える
- 色: `ink` `muted` `subtle` `canvas` `line` `line-strong`（完了チェックの丸枠）`line-dashed`（「タスクを追加」の破線）`brand` `brand-hover` `brand-soft` `brand-dot` `accent` `accent-soft` `danger`（失敗・削除の文字）`danger-dot`（失敗の点）`danger-soft`（エラー背景。未使用）`avatar`
- 影: `shadow-card`（カードのホバー）`shadow-float`（フォームカード）。文字: `text-2xs`（10px。最小サイズ）
- Tailwind v4 は使われたトークンだけ CSS に出す（未使用の `danger-soft` はビルド結果に出ない）。ビルドは圧縮され `rgba(32,36,33,0.18)` → `#2024212e`、`0.213` → `.213` になる
- `spec/assets/design_tokens_spec.rb` がビルド後の CSS（`app/assets/builds/tailwind.css`）を読んで値を検査する。事前に `docker compose run --rm css bin/rails tailwindcss:build` が必要（css コンテナが watch 中なら最新）
- フォーカス表示はビューにクラスを書かず、`@layer base` の `:where(a[href], button, [role=tab], [role=menuitem], [contenteditable=true]):focus-visible` で `ring-2 ring-brand-dot` を一括適用している（`brand-soft` は白地でコントラスト約 1.1:1 で見えないため使わない。入力欄の `focus:ring-brand-soft` は枠線 `border-brand` と併用なので別扱い）
- `<head>` は `layouts/_head.html.erb` に集約（両レイアウトが render）。画面タイトルは `content_for :title`、追加タグは `content_for :head`

## サンプルデータ（`MocksController`）
- 定数ではなく private メソッド（`sample_subtasks` / `sample_parent_tasks` / `date_tabs` / `new_subtask`）。`helper_method` でビューから呼ぶ。リクエストごとに `Time.current` 基準で評価されるので「今日」「明日」が常に成り立つ
- 期限は相対日時（今日 12:00・17:00・18:00／明日 12:00／7 日後 17:00／nil）。サブタスクの期限は親の期限を超えない（「社内提案資料を作成する」は 7 日後 17:00）
- サブタスク 6 件のうち 1 件目が完了済み（`done: true`）、6 件目が期限なし。親タスクに全完了（「経費精算の締め確認」3/3）を含む
- S-5「社内提案資料を作成する」の `done/total` は `sample_subtasks` から導出。他の行の進捗は固定値
- S-5 の親行 `<li>` は `data-done`（`total > 0` かつ `done == total` で "true"）と `data-due-key` を持つ。現状 "true" は「経費精算の締め確認」（3 日後 17:00）だけで、単独の日付グループにしてある（完了済みを隠すと見出しごと隠れる様子を確かめられる）
- S-5 の行は `<li>` がカード（S-4 サブタスクカードと同じ `px-5 py-5 gap-4 rounded-xl`、ホバーで `shadow-card`）。中は `<a>`（ステータス・期限・タイトル・進捗）と行メニュー（`_menu`、`id` は `parent-task-menu-01`… の通し番号、`label` は「『親タスク名』のメニュー」）の兄弟。リンクの中にボタンを入れない
- S-5 の行リンクは `task_detail_mock_path(title:, status:, due:)`（`due` は `%Y-%m-%dT%H:%M`、期限なしは空文字）。S-4 は行の状態・期限で開き、サブタスクはどの行でも同じサンプル。行の期限表示は `data-row-due`
- S-5 の行のフォーカス: `<li>` に `has-[>a:focus-visible]:ring-2 ring-brand-dot`、リンク側は `focus-visible:ring-0`（カード全体を囲み、メニューへのフォーカスでは囲まない。`focus-within` だとメニューでも囲んでしまう）
- S-5 の行は stretched link: `<li>` が `relative`、`<a>` の `after:absolute after:inset-0` でカード全面を当たり判定にする。メニュー（`_menu` のルートは `relative`）は DOM 上でリンクより後ろなので z-index 無しで前面に出る。行メニューに `z-10` 等を付けると、開いたドロップダウンが次の行のメニューの下に潜るので付けない
- S-4 のサブタスク期限（`detail_subtasks`）と追加カード（`new_subtask`）の期限は、親の期限（`@due`）より後なら親の期限に丸める。日付タブは丸めた後の `@subtasks` から作る
- 期限の表示はすべて `DueDateHelper`（`due_label` / `due_key` / `due_time_tag`）を通す。期限は `<time datetime>` で出力され、spec はこれを拾って書式を検査する。カードとタブには `data-due-key`（today / tomorrow / YYYY-MM-DD / none）が付く
- 日付に依存する spec は `travel_to` で固定する（`ActiveSupport::Testing::TimeHelpers` は `rails_helper` で全 spec に include 済み）

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

## モックの共通部品と規約
- **no-op ボタン**: 押しても何も起きない「見た目だけ」のボタンは `type="button" data-mock="noop"` を必ず付ける。削除・再分解などの破壊的な項目も no-op で、確認ダイアログは出さない。`docs/screens.md` の要素表では「（見た目のみ）」と注記する
- **非表示**: 完了フィルタ・日付タブで隠す要素は `data-hidden-by-done` / `data-hidden-by-tab` 属性で表し、`application.css` のレイヤー外ルール（`display: none`）で消す。`hidden` 属性やクラスの付け外しで隠さない（メニュー本体と空状態の表示切替だけは `hidden` 属性）
- `shared/_decomposition_status`（`status: :decomposing | :done | :failed`。ルートに `data-decomposition-status`）: S-4 見出し上・S-5 カードで同じマークアップ。未知の値は例外
- `shared/_menu`（`id:` `items: [{ label:, href:, danger: }]` `placement: :down | :up` `label:`）＋ `menu_controller.js`: `href` 付き項目は `<a role="menuitem">`、無い項目は no-op ボタン。開閉状態はトリガーの `aria-expanded` とメニューの `hidden`。外側クリック・Esc（トリガーへフォーカスを戻す）で閉じ、↑↓/Home/End で項目移動。`id` は画面内で一意にする（サイドバーは `user-menu`）
- `mocks/_content_header`（S-4・S-5 のヘッダー。左はブロックで渡す）＋ `completed_filter_controller.js`: 両画面とも `<header>` と本文を `data-controller="completed-filter"` のラッパーで包む。状態はトグルの `aria-pressed` だけ。ラッパー内の `[data-done]` を対象に、`data-done="true"` へ `data-hidden-by-done` を付け外しする。初期描画でもサーバ側で `data-hidden-by-done` を付けておく（JS 前のちらつき防止・request spec で検査できる）。`MutationObserver` で `data-done` / `data-hidden-by-tab` の変化と要素の追加に追随するので、完了チェックや日付タブ側から通知は不要。`data-completed-filter-target="empty"` の要素は「`[data-done]` の全件が `data-hidden-by-done`」のときだけ `hidden` を外す（＝全完了の空状態）。日付タブなど別理由の 0 件では出さないので、その理由の空状態は絞り込み側で別に持つ。`[data-done]` が 1 件も無い画面でも出さない。`data-completed-filter-target="group"`（S-5 の日付 `<section>`）は、中の `[data-done]` がすべて `data-hidden-by-done` のとき自身にも `data-hidden-by-done` を付けて見出しごと隠す（group 自身は `data-done` を持たないので件数に数えない。初期描画でもサーバ側で付ける）
- `shared/_empty_state`（`icon:` `title:` `body:` `action: { label:, href: }` `data:` `hidden:`）、`shared/_task_progress`（`done:` `total:`。`total` 0 は「—」でバーは `hidden`。バー幅は 100% を上限に丸める。ルートに `data-task-progress`、`total` > 0 なら `role="progressbar"` と `aria-valuenow/max`。S-4 では `subtasks_controller` が `data-task-progress-text/track/bar` を目印に同じ規則で書き換える）
- `_menu` の no-op 項目は押すと閉じてトリガーへフォーカスを戻す。Tab 等でフォーカスがメニュー外へ出ても閉じる。一覧で繰り返すときはトリガーの `label:` を「『対象名』のメニュー」、`id` を番号から作る（S-4 は `task-menu` / `subtask-menu-01`…）
- S-4 サブタスクカード（`mocks/_subtask_card`）: 完了状態は `data-done` だけ。塗り・打ち消し線は `group-data-[done=true]:` の CSS で描き、`subtask_card_controller` は `data-done` と `aria-label`（「〜を完了にする」↔「〜を未完了に戻す」）だけを書き換える。完了で消えたカードからは次の完了チェックへフォーカスを移す。追加用 `<template>` は `number: "__NUMBER__"` で描画し、`subtasks#add` が `replaceAll` で置き換える
- S-4 追加カード: `new_subtask` は `editable: true`・タイトル／補足は空。カードのタスク名・補足は `contenteditable="true"` ＋ `role="textbox"`、プレースホルダは `data-placeholder` を `empty:before:content-[attr(data-placeholder)]` で出す（`aria-placeholder` も同じ文言）。入力前の読み上げ名は `data-subtask-card-default-title-value`（「新しいタスク」）、入力すると `subtask_card#rename` が `titleValue` を更新し、完了チェックと行メニューのトリガー（カード内の `[data-menu-target='trigger']`）の `aria-label` を書き換える。消しきったときブラウザが残す `<br>` は消して `:empty` に戻す。`subtasks#add` は追加後にタスク名へフォーカスし、`subtasks:added` を dispatch する
- S-4 日付タブ（`date_tabs_controller`）: 分解完了のときだけ、`subtasks` と同じ要素に `date-tabs` を付け、`data-action="subtasks:added->date-tabs#showAll"`（追加で「すべて」に戻す）。選択状態はタブの `aria-selected` だけで、下線・文字色は `aria-selected:` の CSS。タブは roving tabindex（選択中だけ 0）で ←→/Home/End は選択も移す（自動選択）。タブの `aria-controls` と一覧を包む `#subtask-panel`（`role="tabpanel"`、`aria-labelledby` は選択中のタブ）。タブのキーは `data-due-key`（`all` / today / tomorrow / YYYY-MM-DD）で、カードの `data-due-key` と一致しないものに `data-hidden-by-tab` を付ける
- S-4 の空状態は 2 つ: 日付タブで 0 件（`data-date-tabs-target="empty"`、「この日のサブタスクはありません」）と全完了（`data-completed-filter-target="empty"`）。タブ側は「`all` 以外を選んでいて、見えるカードが 0 件、かつ全カードが `data-hidden-by-done` ではない」ときだけ出すので排他になる。`date_tabs` は一覧の `data-done` / `data-hidden-by-done` / 子の追加を MutationObserver で追い、自分が付ける `data-hidden-by-tab` は監視しない（ループしない）。進捗はタブで隠れたカードも数える
- `decomposition_progress_controller` はタイマーを `delayValueChanged` / `autoplayValueChanged` で張り直す。system spec では `data-decomposition-progress-delay-value` を `execute_script` で短く書き換えて遷移を待つ（3 秒待たない）

## モック用クエリ（docs には書かない）
- S-4 `/tasks/sample`: `?title=`（見出し。配列・ハッシュ（`?title[]=a`）は無視してサンプル名）、`?status=decomposing|done|failed`（既定・不正値は done）、`?due=`（ISO 8601 の日時。例 `2026-06-20T17:00`。キーが無ければサンプルの期限＝7 日後 17:00、空・不正値は「期限なし」）、`?all_done=1`（status=done のとき全サブタスク完了済み＝全完了の空状態で開く）、`?autoplay=0`（分解中から自動遷移しない）
- S-3 の「200 文字まで」は `#title-hint`（textarea の `aria-describedby`）。S-2 の「（いずれも新しいタブで開きます）」は `#terms-new-tab`（規約リンク 2 本の `aria-describedby`）。チェックボックスの label には入れない（label の名前が変わり `check "利用規約とプライバシーポリシーに同意する"` が壊れる）
- S-3 `/` の送信: GET で `/tasks/sample?title=…&status=decomposing&due=…`（`status` は hidden、`due` は datetime-local の値。未入力でも `due=` は空で付き、S-4 は「期限なし」）。`due` の `min` はサーバの現在時刻（分単位、`include_seconds: false`）。空白だけの入力は `prompt_controller#validate` が `setCustomValidity` で止める（入力例チップは値を入れた後に `input` イベントを dispatch して再検証させる）
- S-1/S-2 の送信: `POST /login` → `mocks#login_submit`、`POST /signup` → `mocks#signup_submit`。保存・検証なしで `redirect_to root_path`（302）。GET だとパスワードがクエリに載るため POST にしている
- S-6 `/terms`・S-7 `/privacy`: auth レイアウトの静的ページ（`mocks/_legal_page`）。S-2 の同意文から `target="_blank" rel="noopener"` で開く（入力途中のフォームを失わない）。本文はダミー
- S-5 `/tasks`: `?empty=1`（親タスクが 1 件も無いときの空状態「まだタスクがありません」。`"1"` 以外の値・配列は通常の一覧）
- 分解中は `decomposition_progress_controller` が 3 秒後に `status=done`（`title` `due` は引き継ぐ）へ `Turbo.visit(..., { action: "replace" })`
- 部品の単体検査は `spec/views/shared/`（view spec）
- `_auth_field`（`id:` `label:` `type:`、任意 `placeholder:` `autocomplete:` `hint:` `minlength:` `required:`）: `required` は既定で付く。`hint:` は `id="<id>-hint"` で出し、入力欄の `aria-describedby` に結ぶ
- system spec で `minlength` を検証するときは `send_keys` で打ち込む（`fill_in` の値設定はユーザー編集扱いにならず `tooShort` が立たない）
