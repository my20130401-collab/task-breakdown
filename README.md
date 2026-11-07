# Tasklet — AI タスク分解アプリ

「見積もり作成」「起案書作成」のような大まかなタスクを入力すると、AI が実行できる手順（サブタスク）に分解し、期限から逆算して進められるようにするアプリです。
仕事の進め方や所要時間をまだ予測しにくい新入社員が、ベテランのように段取りを組めることを目指しています。

## 使ってみる

**`https://task-breakdown-kw8v.onrender.com`** を開くと、ブラウザ（PC 版の Chrome / Edge / Safari）ですぐに使えます。

1. **会員登録** — お名前・メールアドレス・パスワード（8 文字以上）を入力し、利用規約とプライバシーポリシーに同意してアカウントを作ります（メールの確認はありません）
2. **やりたいことを入力** — 「今日は何に取り組みますか？」の欄に、たとえば「来週の経営会議に向けて提案資料を作る」と入力し、必要なら期限を選んで「タスクを分解する」を押します
3. **AI が手順に分解** — 通常 30 秒以内に、3〜8 件ほどの手順（サブタスク）が画面に表示されます（再読み込みは不要）。他の人の確認・承認待ちが発生する手順には「特殊」の印が付くので、早めに着手します
4. **手順を進める** — 手順の丸いチェックで完了にでき、完了した手順は一覧から隠れます。「タスクを追加」で自分の知っている手順を足したり、メニュー「…」から名前・補足・期限を編集・削除したりできます
5. **マイタスクで確認** — 左のメニューの「マイタスク」に、入力したタスクが期限の近い順に並び、進み具合（例：2/5 完了）が分かります

- 無料のサーバで動かしているため、しばらくアクセスが無かったあとの最初の表示には 1 分ほどかかることがあります。エラーではないので、そのままお待ちください
- 入力したタスクの内容は、手順に分解するため OpenAI の API に送信します。第三者の個人情報や機密情報は入力しないでください
- ハッカソン用のデモです。詳しくは利用規約（`https://task-breakdown-kw8v.onrender.com/terms`）とプライバシーポリシー（`https://task-breakdown-kw8v.onrender.com/privacy`）をご覧ください。会員登録画面の同意欄からも開けます

## はじめての方へ

開発に参加する方は、次の順番で進めてください。

1. **[開発環境の構築](docs/dev/setup.md)** — Docker と Git の準備から、アプリの起動・テストの実行まで（初めてでも順番どおりに進めれば完了します）
2. **[開発の進め方](docs/dev/first-contribution.md)** — Issue の選び方、ブランチ、コミット、Pull Request を出すまで
3. **[キックオフ資料](docs/kickoff.md)** — プロダクトの目的、チームの役割、開発ルール

困ったら Mattermost の「Bチーム NCT × RUNTEQハッカソン」チャンネルで質問してください。

## タスク管理

| リンク | 内容 |
|---|---|
| [カンバン（GitHub Projects）](https://github.com/users/hisaju/projects/8/views/2) | Issue の状況（Backlog / Ready / In Progress / Review / Done）。着手する Issue はここの Ready 列から選ぶ |
| [マイルストーン](https://github.com/hisaju/task-breakdown/milestones) | MVP までのマイルストーンと期限 |
| [エピック一覧](https://github.com/hisaju/task-breakdown/issues?q=is%3Aissue+label%3Aepic) | MVP までの大きな要件（エピック）と進み具合 |

## クイックスタート

Docker Desktop と Git が入っていれば、次のコマンドで起動できます（詳しくは [開発環境の構築](docs/dev/setup.md)）。

```bash
git clone git@github.com:hisaju/task-breakdown.git
cd task-breakdown
docker compose build
docker compose run --rm web bin/rails db:prepare
docker compose up -d
```

http://localhost:3000 を開くとログイン画面が表示されます。最初は「会員登録」からアカウントを作ってください。停止は `docker compose stop` です。

| 画面 | URL | ログイン |
|---|---|---|
| タスクを作る（ホーム） | http://localhost:3000/ | 必要 |
| マイタスク | http://localhost:3000/tasks | 必要 |
| タスク詳細 | http://localhost:3000/tasks/:id（マイタスクからタスクを選んで開く） | 必要 |
| 会員登録 | http://localhost:3000/registration/new | 不要 |
| ログイン | http://localhost:3000/session/new | 不要 |
| 利用規約 | http://localhost:3000/terms | 不要 |
| プライバシーポリシー | http://localhost:3000/privacy | 不要 |

手元の開発サーバとテストは、OpenAI の API キー無しで、固定の手順（「見積もり作成」の 3 件）を返すテスト用の分解で動きます。実際の AI の分解を確かめるときは、評価コマンドにだけキーを渡します（`docker compose run --rm -e OPENAI_API_KEY=<API キー> web bin/rails eval:decompose`。シェルの環境変数に `OPENAI_API_KEY` があるなら `-e OPENAI_API_KEY` だけでよい）。

## よく使うコマンド

Rails のコマンドは、パソコンで直接ではなく `docker compose run --rm web` を付けてコンテナの中で実行します。

| 用途 | コマンド |
|---|---|
| テスト | `docker compose run --rm web bundle exec rspec` |
| コードの書き方チェック | `docker compose run --rm web bin/rubocop` |
| セキュリティ診断 | `docker compose run --rm web bin/brakeman` |
| ログを見る | `docker compose logs -f web` |
| CSS を作り直す | `docker compose run --rm css bin/rails tailwindcss:build` |
| AI 分解の品質評価（OpenAI の API キーが必要） | `docker compose run --rm -e OPENAI_API_KEY=<API キー> web bin/rails eval:decompose` |

ほかのコマンドとトラブル対処は [開発環境の構築](docs/dev/setup.md#6-よく使うコマンド) にまとめています。

## ドキュメント

### 仕様

| ドキュメント | 内容 |
|---|---|
| [キックオフ資料](docs/kickoff.md) | 目的とゴール、チームの役割、スケジュール、技術スタック、開発フロー、テスト方針、タスク管理、コミュニケーション |
| [要件定義](docs/requirements.md) | ペルソナ、ユースケース、ユーザーストーリー、受入条件 |
| [画面設計](docs/screens.md) | 画面一覧、画面遷移図、各画面の要素と操作 |
| [データ設計](docs/data-model.md) | ER 図、テーブル定義 |
| [AI タスク分解の設計](docs/ai-decomposition.md) | 処理の流れ、プロンプト、出力形式、失敗時の挙動、品質評価 |
| [運用手順書](docs/deploy.md) | デプロイ、本番の環境変数、無料枠の制限とスリープ対策 |

### 開発者向け

| ドキュメント | 内容 |
|---|---|
| [開発環境の構築](docs/dev/setup.md) | 必要なもの、起動、テスト、毎日の始め方、トラブル対処 |
| [開発の進め方](docs/dev/first-contribution.md) | Issue → ブランチ → 実装 → コミット → Pull Request の手順 |
| [CLAUDE.md](CLAUDE.md) | Claude Code で開発するときの前提（Claude Code が自動で読み込みます） |

## 技術スタック

Ruby 3.4 / Rails 8.1 / PostgreSQL 17 / Hotwire（Turbo・Stimulus）/ Tailwind CSS v4 / RSpec / Docker Compose

## ディレクトリ構成（主なもの）

```
app/
  controllers/        画面ごとの処理
  views/              画面の HTML（ERB）
  javascript/controllers/  画面の動き（Stimulus）
  assets/tailwind/    色・文字などのデザイン設定
config/routes.rb      URL と処理の対応
spec/                 テスト（RSpec）
docs/                 仕様書
docs/dev/             開発者向けガイド
```
