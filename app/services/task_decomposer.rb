# 親タスクを受け取り、LLM による分解、検証・整形、サブタスクの保存を一括して担うサービスクラス
class TaskDecomposer
  MAX_SUBTASKS_COUNT = 12
  MAX_TITLE_LENGTH = 200

  attr_reader :task, :decomposition, :client

  # @param task [Task] 分解対象の親タスク
  # @param decomposition [Decomposition, nil] 履歴レコード（未指定時は新規作成）
  # @param client [Object, nil] LLM クライアント（未指定時は Llm::Client.build）
  def initialize(task:, decomposition: nil, client: nil)
    @task = task
    @decomposition = decomposition || task.decompositions.build
    @client = client || Llm::Client.build
  end

  # タスク分解処理を実行する
  # @return [Boolean] 成功時は true、失敗時は false
  def call
    @decomposition.update!(status: :pending) if @decomposition.persisted?

    prompt = build_prompt
    response = @client.decompose(prompt: prompt)

    subtasks_data = extract_and_sanitize_subtasks(response)
    if subtasks_data.empty?
      fail_decomposition!("AI の応答に有効なサブタスクが含まれていません")
      return false
    end

    save_subtasks!(subtasks_data, response)
    true
  rescue StandardError => e
    fail_decomposition!(e.message)
    false
  end

  private

  # プロンプト文の構築
  def build_prompt
    system_part = TaskDecomposer::Prompt.system_prompt
    user_part = TaskDecomposer::Prompt.build_user_prompt(@task)
    "#{system_part}\n\n#{user_part}"
  end

  # AI からのレスポンスを検品・整形する
  def extract_and_sanitize_subtasks(response)
    raw_subtasks = response[:subtasks] || []
    return [] if raw_subtasks.empty?

    # 13 件以上の場合は先頭 12 件のみ採用
    target_subtasks = raw_subtasks.first(MAX_SUBTASKS_COUNT)

    sanitized = []
    target_subtasks.each do |subtask|
      title = subtask[:title]&.to_s&.strip
      next if title.blank? # タイトルが空の要素は除外

      # 200 文字を超える場合は切り詰め
      title = title.truncate(MAX_TITLE_LENGTH, omission: "")

      sanitized << {
        title: title,
        description: subtask[:description],
        kind: subtask[:kind] == "special" ? :special : :basic,
        due_at: sanitize_due_at(subtask[:due_at])
      }
    end

    sanitized
  end

  # 期限日時の検証と親タスク期限への丸め処理
  def sanitize_due_at(raw_due_at)
    return nil if raw_due_at.blank?

    parsed_time = Time.zone.parse(raw_due_at.to_s) rescue nil
    return nil if parsed_time.nil?

    # 親タスクに期限があり、サブタスク期限がそれを超える場合は親タスクの期限に丸める
    if @task.due_at.present? && parsed_time > @task.due_at
      @task.due_at
    else
      parsed_time
    end
  end

  # 検品済みのサブタスクと Decomposition 履歴をトランザクション内で保存
  def save_subtasks!(subtasks_data, raw_response)
    ActiveRecord::Base.transaction do
      subtasks_data.each_with_index do |data, index|
        @task.children.create!(
          user: @task.user,
          title: data[:title],
          description: data[:description],
          kind: data[:kind],
          due_at: data[:due_at],
          position: index + 1,
          source: :ai
        )
      end

      @decomposition.update!(
        status: :succeeded,
        response_payload: raw_response,
        error_message: nil
      )
    end
  end

  # 失敗時の Decomposition レコード更新
  def fail_decomposition!(message)
    @decomposition.update(
      status: :failed,
      error_message: message
    )
  end
end
