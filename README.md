# Tasklet — AI タスク分解アプリ

「見積もり作成」「起案書作成」のような大まかなタスクを入力すると、AI が実行できる手順（サブタスク）に分解し、期限から逆算して進められるようにするアプリです。
仕事の進め方や所要時間をまだ予測しにくい新入社員が、ベテランのように段取りを組めることを目指しています。

会員登録してタスクを入力すると、AI（OpenAI の API）が 3〜8 件程度のサブタスクに分解して保存します。分解した手順は追加・編集・削除でき、完了にすると一覧から隠れます。

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
