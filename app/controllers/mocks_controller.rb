# 画面モック用コントローラ。表示用のサンプルデータのみを持ち、永続化や AI 分解は行わない。
# サンプルの期限は Time.current 基準の相対日時で、リクエストごとに評価する（「今日」「明日」が常に成り立つ）。
class MocksController < ApplicationController
  # 画面モック（デザイン・UI確認用）のため、未ログイン状態でのアクセスを許可する
  allow_unauthenticated_access
  before_action :resume_session

  EXAMPLES = %w[イベントの企画を進める 資格試験の学習計画を立てる 引っ越しの準備をする].freeze

  # S-4 で表示する分解結果の親タスク名（S-5 の同名の行は進捗をこのサンプルから導出する）
  SAMPLE_PARENT_TITLE = "社内提案資料を作成する".freeze

  # S-4 の分解ステータス（?status=）。これ以外の値・未指定は :done
  DECOMPOSITION_STATUSES = %w[decomposing done failed].freeze

  helper_method :sample_subtasks, :sample_parent_tasks, :date_tabs, :new_subtask

  def new_task
  end

  # モック用クエリ: ?empty=1（タスクが 1 件も無いときの空状態。説明は .claude/knowledge/repo.md）
  def my_tasks
    @parent_tasks = params[:empty] == "1" ? [] : sample_parent_tasks
  end

  def signup
    render layout: "auth"
  end

  def login
    render layout: "auth"
  end

  # S-1/S-2 の送信。保存・認証は行わず、ログイン後のホーム（S-3）へ移る。
  # POST で受けるので、入力値（パスワードを含む）が URL に残らない
  def signup_submit
    user = User.first_or_create!(
      email_address: "mock@example.com"
    ) do |u|
      u.name = "モックユーザー"
      u.password = "password123"
      u.terms_accepted_at = Time.current
    end

    start_new_session_for(user)
    redirect_to root_path
  end

  def login_submit
    user = User.first_or_create!(
      email_address: "mock@example.com"
    ) do |u|
      u.name = "モックユーザー"
      u.password = "password123"
      u.terms_accepted_at = Time.current
    end

    start_new_session_for(user)
    redirect_to root_path
  end

  def terms
    render layout: "auth"
  end

  def privacy
    render layout: "auth"
  end

  # モック用クエリ: ?title= ?status= ?due= ?all_done=1 ?autoplay=0（説明は .claude/knowledge/repo.md）
  def task_detail
    @title = string_param(:title).presence || SAMPLE_PARENT_TITLE
    @status = params[:status].presence_in(DECOMPOSITION_STATUSES)&.to_sym || :done
    @due = params.key?(:due) ? parse_due(params[:due]) : sample_parent_due
    @subtasks = detail_subtasks
    @autoplay = params[:autoplay] != "0"
    # 自動遷移先は title・due を引き継ぐ（見出しと同じく、文字列でない値は引き継がない）
    @done_url = task_detail_mock_path({ title: string_param(:title), due: string_param(:due) }.compact.merge(status: "done"))
  end

  private

  # S-4 のサブタスク（番号順）。完了済み 1 件・期限なし 1 件（末尾）を含む
  def sample_subtasks
    @sample_subtasks ||= [
      { kind: :basic, due: today_at(17), done: true,
        title: "依頼の背景と締め切りを確認する", description: "依頼者に目的・提出先・締め切りを確認する" },
      { kind: :basic, due: today_at(17), done: false,
        title: "目的と読み手を整理する", description: "誰に何を伝える資料か、ゴールを1文で定義する" },
      { kind: :basic, due: today_at(17), done: false,
        title: "必要な情報を集める", description: "過去資料・数値・関係者の意見をまとめる" },
      { kind: :special, due: days_later_at(1, 12), done: false,
        title: "上長に方向性を確認する", description: "構成案を共有し、認識のずれがないか確認する" },
      { kind: :basic, due: days_later_at(7, 17), done: false,
        title: "初稿を作成する", description: "見出しに沿って本文と図表を作成する" },
      { kind: :basic, due: nil, done: false,
        title: "提出後に振り返りをメモする", description: "指摘された点と次回に活かすことを書き残す" }
    ]
  end

  # S-5 の親タスク（期限の近い順、期限なしは末尾）。
  # SAMPLE_PARENT_TITLE の進捗は sample_subtasks から導出し、他の行は固定値。
  # 全完了の「経費精算の締め確認」は単独の日付グループに置く（完了済みを隠すと見出しごと隠れる）
  def sample_parent_tasks
    @sample_parent_tasks ||= [
      { title: "経費申請", due: today_at(17), status: :decomposing, done: 0, total: 0 },
      { title: "見積もり作成", due: today_at(18), status: :done, done: 1, total: 3 },
      { title: "起案書作成", due: days_later_at(1, 12), status: :done, done: 0, total: 6 },
      { title: "経費精算の締め確認", due: days_later_at(3, 17), status: :done, done: 3, total: 3 },
      { title: SAMPLE_PARENT_TITLE, due: days_later_at(7, 17), status: :done,
        done: sample_subtasks.count { it[:done] }, total: sample_subtasks.size },
      { title: "引っ越しの準備をする", due: nil, status: :failed, done: 0, total: 0 }
    ]
  end

  # S-4 の日付タブ。「すべて」＋表示するサブタスクの期限に含まれる日付（期限なしは「すべて」のみで表示）
  def date_tabs
    dated = (@subtasks || sample_subtasks).filter_map { it[:due] }.sort.uniq { helpers.due_key(it) }
    [ { key: "all", label: "すべて" } ] +
      dated.map { { key: helpers.due_key(it), label: helpers.due_label(it, date_only: true) } }
  end

  # S-4 に並べるサブタスク。分解中・分解失敗は 0 件、?all_done=1 は全件完了済み。
  # 期限は親タスクの期限を超えないよう丸める（S-5 のどの行から開いても、サブタスクが親より後の期限にならない）
  def detail_subtasks
    return [] unless @status == :done

    sample_subtasks.map do |subtask|
      subtask.merge(due: within_parent_due(subtask[:due]), done: params[:all_done] == "1" || subtask[:done])
    end
  end

  # 親タスクの期限より後の期限は親の期限にする。親の期限が無いとき・サブタスクの期限が無いときはそのまま
  def within_parent_due(due)
    return due if due.nil? || @due.nil?

    [ due, @due ].min
  end

  # 親タスクの期限のサンプル（S-5 の同名の行と同じ）
  def sample_parent_due
    sample_parent_tasks.find { it[:title] == SAMPLE_PARENT_TITLE }[:due]
  end

  # クエリの値を文字列として読む。?title[]=a のような配列・ハッシュは無いものとして扱う
  def string_param(key)
    value = params[key]
    value.is_a?(String) ? value : nil
  end

  # ?due= は ISO 8601 の日時（S-3 の datetime-local の値。例: 2026-06-20T17:00）だけを受け付け、それ以外は期限なし
  def parse_due(value)
    Time.zone.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  # 「タスクを追加」で末尾に足すカードの初期値。期限は今日 17:00（親の期限がそれより前なら親の期限）。
  # タスク名・補足は空で、追加直後に入力する（editable: true）
  def new_subtask
    { kind: :basic, due: within_parent_due(today_at(17)), done: false, title: "", description: "", editable: true }
  end

  def today_at(hour)
    days_later_at(0, hour)
  end

  def days_later_at(days, hour)
    Time.current.beginning_of_day.advance(days:).change(hour:)
  end
end
