# 横断検査（spec/requests/pages_*_spec.rb）で巡回する画面と、検査用の HTML の読み方。
# 画面や状態を足したら PUBLIC_PATHS / AUTHENTICATED_PAGES にも足す（巡回から漏れた画面は検査されない）
module Pages
  # ログイン前の画面（S-1 ログイン, S-2 会員登録, S-6 利用規約, S-7 プライバシーポリシー）。そのまま GET する
  PUBLIC_PATHS = %w[
    /session/new
    /registration/new
    /terms
    /privacy
  ].freeze

  # ログイン後の画面。キーは巡回名（describe に出る）、値は準備するデータの種類（authenticated_page_path を参照）。
  # URL がタスクの id を含むため、ログインとデータの用意をしてから開く
  AUTHENTICATED_PAGES = {
    "/（S-3 タスク作成）" => :new_task,
    "/tasks（S-5 マイタスク。データあり）" => :tasks,
    "/tasks（S-5 マイタスク。0 件）" => :tasks_empty,
    "/tasks/:id（S-4 タスク詳細。分解中）" => :task_decomposing,
    "/tasks/:id（S-4 タスク詳細。分解完了）" => :task_decomposed,
    "/tasks/:id（S-4 タスク詳細。分解失敗）" => :task_decomposition_failed,
    "/tasks/:id（S-4 タスク詳細。全完了）" => :task_all_subtasks_done,
    "/tasks/:id/edit（タスク編集）" => :task_edit
  }.freeze

  # S-4 の状態ごとに使う Task ファクトリの trait（spec/factories/tasks.rb）
  S4_TRAITS = {
    task_decomposing: :decomposing,
    task_decomposed: :decomposed,
    task_decomposition_failed: :decomposition_failed,
    task_all_subtasks_done: :all_subtasks_done
  }.freeze

  # 巡回する全画面の名前（ログイン前はパスそのもの）
  ALL = (PUBLIC_PATHS + AUTHENTICATED_PAGES.keys).freeze

  # 外部への参照として許すホスト（Web フォント）。<a href> / <form action> には外部 URL を置かない
  ALLOWED_EXTERNAL_HOSTS = %w[fonts.googleapis.com fonts.gstatic.com].freeze

  # デザイントークンを使わずに書いた色・文字サイズ（16 進の色、rgba()、10px 未満の文字）
  BANNED_VALUES = /#\h{6}\b|rgba\(|text-\[9px\]/

  # 巡回名の画面を開く（ログイン後の画面は、新しいユーザーでログインし、データを用意してから GET する）
  def get_page(name)
    get(PUBLIC_PATHS.include?(name) ? name : authenticated_page_path(AUTHENTICATED_PAGES.fetch(name)))
  end

  # 描画された HTML を読む。<template> は除く。
  # Nokogiri は template の中身も通常の要素として読むため、そのままだとひな形の id や属性が
  # 画面上の要素として数えられてしまう
  def pages_document(body = response.body)
    Nokogiri::HTML(body).tap { |doc| doc.css("template").each(&:remove) }
  end

  # 違反の報告に使う要素の名前（aria-label → 文字列 → id の順）
  def element_name(node)
    node["aria-label"].presence || node.text.squish.presence || node["id"].presence || node.name
  end

  private

  # ログインして、画面の状態に合わせたデータを用意し、開く URL を返す
  def authenticated_page_path(kind)
    # 同じ example で続けて開くとき、前の画面のログインが残っているとログインし直せない（ログイン済みは S-3 へ戻される）
    reset!
    user = FactoryBot.create(:user)
    post session_path, params: { email_address: user.email_address, password: user.password }

    case kind
    when :new_task then root_path
    when :tasks_empty then tasks_path
    when :tasks then tasks_with_data_path(user)
    when :task_edit then edit_task_path(FactoryBot.create(:task, user:))
    else task_path(FactoryBot.create(:task, S4_TRAITS.fetch(kind), user:, title: "見積書を提出する"))
    end
  end


  # S-5: 日付グループが複数あり、進捗あり・進捗なし（—）・全完了・期限なしの行を含む
  def tasks_with_data_path(user)
    FactoryBot.create(:task, :decomposed, user:, title: "見積書を提出する")
    FactoryBot.create(:task, :decomposing, user:, title: "週報を書く", due_at: 2.days.from_now)
    FactoryBot.create(:task, :all_subtasks_done, user:, title: "経費精算の締め確認", due_at: 3.days.from_now)
    FactoryBot.create(:task, :without_due_at, user:, title: "資格試験の学習計画を立てる")
    tasks_path
  end
end

RSpec.configure do |config|
  config.include Pages, type: :request
end
