# 開発環境の構築

このリポジトリを手元のパソコンで動かし、テストが通る状態にするまでの手順です。
上から順番に進めれば、プログラミングの経験が浅くても 30〜60 分ほどで終わります。

> **Ruby や PostgreSQL をパソコンに直接インストールする必要はありません。**
> アプリもデータベースも Docker の「コンテナ」の中で動きます。パソコンに入れるのは Docker と Git だけです。

## ゴール

- ブラウザで http://localhost:3000 を開くとアプリの画面が表示される
- テスト（RSpec）がすべて成功する

## 最初に知っておくとよい言葉

| 言葉 | ざっくりした意味 |
|---|---|
| ターミナル | コマンドを打ち込んで操作する画面。Mac は「ターミナル」アプリ、Windows は WSL の「Ubuntu」アプリを使う |
| Git | ファイルの変更履歴を管理する道具 |
| GitHub | Git のリポジトリ（ソースコード一式）を置いて、チームで共有するサービス |
| Docker | アプリを動かすための環境を「コンテナ」という箱にまとめて動かす道具。全員が同じ環境で開発できる |
| コンテナ | Docker が動かす小さな仮想環境。このプロジェクトでは `web`（アプリ）・`db`（データベース）・`css`（見た目のビルド）の 3 つを使う |
| Rails | このアプリで使っている Web アプリのフレームワーク（Ruby 製） |

コマンドの例で `$` から始まる行は「ターミナルに打ち込む行」です。`$` 自体は入力しません。

---

## 1. 必要なものを準備する

### 1-1. パソコン

- **Mac**（Apple シリコン／Intel どちらでも可）
- **Windows** の場合は **WSL2（Ubuntu）** を使います。PowerShell やコマンドプロンプトではなく、Ubuntu のターミナルで作業してください
  - WSL2 の導入: PowerShell を管理者として開き `wsl --install` を実行 → 再起動 → 「Ubuntu」アプリを起動してユーザー名とパスワードを設定

### 1-2. Docker Desktop

1. [Docker Desktop](https://www.docker.com/products/docker-desktop/) をダウンロードしてインストールする
   - Windows はインストール時に「Use WSL 2」を有効にする
2. Docker Desktop を起動する（画面上部／タスクバーにクジラのアイコンが出れば起動中）
3. ターミナルで次を実行し、バージョンが表示されることを確認する

```bash
$ docker --version
$ docker compose version
```

> メモリが足りないと動作が不安定になります。Docker Desktop の Settings → Resources で **メモリ 4GB 以上** を割り当ててください。

### 1-3. Git

```bash
$ git --version
```

バージョンが表示されれば OK です。表示されない場合:

- Mac: `xcode-select --install` を実行してインストールする
- Windows（Ubuntu）: `sudo apt update && sudo apt install -y git`

初回だけ、コミットに記録される名前とメールアドレスを設定します（GitHub に登録したものと同じにしてください）。

```bash
$ git config --global user.name "山田 太郎"
$ git config --global user.email "you@example.com"
```

### 1-4. GitHub アカウントとリポジトリへの招待

1. GitHub アカウントを作成する（持っていれば不要）
2. リポジトリ（非公開）への招待をチームに依頼し、届いたメールから招待を承認する

### 1-5. SSH 鍵を GitHub に登録する

パスワードを毎回入力せずに GitHub とやりとりするための設定です。

```bash
# 鍵を作る（質問はすべて Enter でよい）
$ ssh-keygen -t ed25519 -C "you@example.com"

# 公開鍵を表示してコピーする
$ cat ~/.ssh/id_ed25519.pub
```

GitHub の右上アイコン → **Settings → SSH and GPG keys → New SSH key** に、コピーした内容を貼り付けて保存します。

```bash
# つながるか確認（初回は yes と入力）
$ ssh -T git@github.com
# 「Hi <ユーザー名>! You've successfully authenticated」と出れば成功
```

### 1-6. エディタ

[Visual Studio Code](https://code.visualstudio.com/) をおすすめします（Windows は拡張機能「WSL」を入れ、Ubuntu 側のフォルダを開いてください）。

### 1-7. GitHub CLI（任意）

ターミナルから Pull Request を作れる道具です。なくても GitHub の画面から同じことができます。

```bash
# Mac
$ brew install gh
# 共通（インストール後にログイン）
$ gh auth login
```

---

## 2. リポジトリを手元にコピーする（clone）

作業用のフォルダに移動してから clone します。

```bash
$ mkdir -p ~/projects && cd ~/projects
$ git clone git@github.com:hisaju/task-breakdown.git
$ cd task-breakdown
```

> Windows（WSL）では、`/mnt/c/...`（C ドライブ）ではなく、`~/projects` のような **Ubuntu 側のフォルダ**に clone してください。C ドライブ側に置くと動作が非常に遅くなります。

以降のコマンドは、すべて `task-breakdown` フォルダの中で実行します。

---

## 3. 起動する

### 3-1. コンテナを作る（初回のみ・5〜10 分）

```bash
$ docker compose build
```

Ruby やライブラリ（gem）、テスト用ブラウザなどをコンテナに入れます。初回は時間がかかります。

### 3-2. データベースを作る（初回のみ）

```bash
$ docker compose run --rm web bin/rails db:prepare
```

`Created database 'task_breakdown_development'` と `Created database 'task_breakdown_test'` が表示されれば成功です。

### 3-3. アプリを起動する

```bash
$ docker compose up -d
```

`-d` は「裏で動かし続ける」という意味です。起動には 10〜20 秒ほどかかります。

### 3-4. ブラウザで開く

http://localhost:3000 を開き、ログイン画面（「おかえりなさい」）が表示されれば成功です。「会員登録」から自分用のアカウントを作ると、「今日は何に取り組みますか？」の画面に移ります（手元のデータベースに保存されるだけで、メールは送られません）。

| 画面 | URL | ログイン |
|---|---|---|
| タスクを作る（ホーム） | http://localhost:3000/ | 必要 |
| マイタスク | http://localhost:3000/tasks | 必要 |
| タスク詳細 | http://localhost:3000/tasks/:id（マイタスクからタスクを選んで開く） | 必要 |
| 会員登録 | http://localhost:3000/registration/new | 不要 |
| ログイン | http://localhost:3000/session/new | 不要 |
| 利用規約 | http://localhost:3000/terms | 不要 |
| プライバシーポリシー | http://localhost:3000/privacy | 不要 |

AI 分解は、リポジトリ直下の `.env` に `OPENAI_API_KEY=<API キー>` を書いて `docker compose up -d` し直すと OpenAI の API で動き、`.env` が無ければ API を使わない固定の分解（「見積もり作成」の 3 件）で動きます（`.env` はコミットしません）。

### 3-5. 止める・再開する

```bash
$ docker compose stop      # 止める（データは残る）
$ docker compose up -d     # 再開する
$ docker compose ps        # 動いているコンテナを確認する
```

---

## 4. テストを動かす

```bash
# テスト（RSpec）をすべて実行
$ docker compose run --rm web bundle exec rspec

# コードの書き方チェック（RuboCop）
$ docker compose run --rm web bin/rubocop
```

最後に `0 failures`（テスト）と `no offenses detected`（RuboCop）が出れば、環境構築は完了です。
テストはブラウザを動かすものも含むため、数分かかります。

ファイルを 1 つだけ実行したいときは、パスを付けます。

```bash
$ docker compose run --rm web bundle exec rspec spec/requests/tasks_spec.rb
```

---

## 5. 毎日の作業の始め方

```bash
$ git switch main          # main ブランチに切り替える
$ git pull                 # 最新の状態を取り込む
$ docker compose up -d     # アプリを起動する
```

`git pull` のあと、次のファイルが変わっていたら追加の作業が必要です。

| 変わったファイル | やること |
|---|---|
| `Gemfile` / `Gemfile.lock` | `docker compose build` → `docker compose up -d` |
| `Dockerfile.dev` / `compose.yaml` | `docker compose build` → `docker compose up -d` |
| `db/migrate/` 配下 | `docker compose run --rm web bin/rails db:prepare` |

作業の進め方（ブランチの作り方から Pull Request まで）は [開発の進め方](first-contribution.md) を見てください。

---

## 6. よく使うコマンド

**ポイント: Rails のコマンドは必ず `docker compose run --rm web` を前に付けて、コンテナの中で実行します。**
（パソコンに Ruby が入っていても、そのまま `bin/rails` を実行するとデータベースにつながりません）

| やりたいこと | コマンド |
|---|---|
| アプリを起動 | `docker compose up -d` |
| アプリを停止 | `docker compose stop` |
| ログを見る（Ctrl + C で終了） | `docker compose logs -f web` |
| テストを実行 | `docker compose run --rm web bundle exec rspec` |
| コードの書き方チェック | `docker compose run --rm web bin/rubocop` |
| 書き方の自動修正 | `docker compose run --rm web bin/rubocop -a` |
| セキュリティ診断 | `docker compose run --rm web bin/brakeman` |
| ルーティング（URL 一覧）を見る | `docker compose run --rm web bin/rails routes` |
| Rails コンソール | `docker compose run --rm web bin/rails console` |
| CSS を作り直す | `docker compose run --rm css bin/rails tailwindcss:build` |
| データベースを作る・更新する | `docker compose run --rm web bin/rails db:prepare` |

---

## 7. うまくいかないとき

| 症状 | 原因と対処 |
|---|---|
| `Cannot connect to the Docker daemon` / `failed to connect to the docker API` | Docker Desktop が起動していません。起動してクジラのアイコンが出るまで待ってから、もう一度実行します |
| `Bind for 0.0.0.0:3000 failed: port is already allocated` | 別のアプリが 3000 番ポートを使っています。そのアプリを止めるか、`PORT=3001 docker compose up -d` で別のポートを使い、http://localhost:3001 を開きます |
| 画面の見た目（色や余白）が崩れている・変更が反映されない | `docker compose run --rm css bin/rails tailwindcss:build` を実行してからブラウザを再読み込みします |
| `A server is already running` と出て web が起動しない | `docker compose restart web` を実行します |
| `Could not find gem ...` / `Bundler::GemNotFound` | `git pull` で gem が増えています。`docker compose build` → `docker compose up -d` を実行します |
| `ActiveRecord::PendingMigrationError` / データベースのエラー | `docker compose run --rm web bin/rails db:prepare` を実行します |
| テストで `Ferrum::...` や `Chrome` 関係のエラー | テスト用ブラウザが古い可能性があります。`docker compose build` を実行してから再度テストします |
| 何をしても直らない | 下の「環境を作り直す」を試します |
| ブラウザで開くとエラー画面が出る | `docker compose logs -f web` でログを見ると、原因（赤字やエラー名）が分かることが多いです |

### 環境を作り直す

> **注意:** 次のコマンドは手元のデータベースの中身を消します（手元で作ったアカウントやタスクもすべて消えます）。

```bash
$ docker compose down -v
$ docker compose build
$ docker compose run --rm web bin/rails db:prepare
$ docker compose up -d
```

### それでも解決しないとき

30 分調べても解決しなければ、ひとりで抱え込まずに Mattermost の「Bチーム NCT × RUNTEQハッカソン」チャンネルで質問してください。
質問のテンプレートは [キックオフ資料の (9) コミュニケーションルール](../kickoff.md#9-コミュニケーションルール) にあります。
エラーメッセージは画面のスクリーンショットではなく、**文字をコピーして**貼ると早く解決します。

---

## 付録: このプロジェクトのコンテナ構成

| コンテナ | 役割 | 中で動いているもの |
|---|---|---|
| `web` | アプリ本体 | Rails サーバー（http://localhost:3000） |
| `db` | データベース | PostgreSQL 17 |
| `css` | 見た目のビルド | Tailwind CSS（ファイルの変更を見張って CSS を自動で作り直す） |

手元のファイルはコンテナの中と共有されているので、エディタでファイルを保存すると、ブラウザの再読み込みだけで変更が反映されます（`Gemfile` や設定ファイルを変えたときは再起動が必要です）。
