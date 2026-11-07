require "rails_helper"

RSpec.describe "Tasks::Subtasks (UC-3)" do
  let(:user) { User.create!(name: "Request Tester", email_address: "req_tester@example.com", password: "password", terms_accepted_at: Time.current) }
  let(:parent_task) { user.tasks.create!(title: "親タスク", due_at: 1.day.from_now) }
  let!(:subtask) { parent_task.children.create!(user: user, title: "既存のサブタスク") }

  before do
    # ログイン処理
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  describe "GET /tasks/:task_id/subtasks/new" do
    it "Turbo Stream形式で新規フォームを返すこと (AC-1)" do
      get new_task_subtask_path(parent_task), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include('turbo-stream action="append" target="subtasks-list"')
    end
  end

  describe "POST /tasks/:task_id/subtasks" do
    context "有効なパラメータの場合" do
      it "サブタスクを作成し、Turbo Streamで置換命令を返すこと (AC-2)" do
        expect {
          post task_subtasks_path(parent_task), params: { task: { title: "新しいタスク", description: "補足" } }, as: :turbo_stream
        }.to change(parent_task.children, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include('turbo-stream action="replace" target="subtasks_area"')
      end
    end
  end

  describe "GET /tasks/:task_id/subtasks/:id/edit" do
    it "Turbo Stream形式で編集フォームを返すこと (AC-3)" do
      get edit_task_subtask_path(parent_task, subtask), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include(%(turbo-stream action="replace" target="task_#{subtask.id}"))
    end
  end

  describe "PATCH /tasks/:task_id/subtasks/:id" do
    context "有効なパラメータの場合" do
      it "サブタスクを更新し、Turbo Streamで置換命令を返すこと (AC-3)" do
        patch task_subtask_path(parent_task, subtask), params: { task: { title: "更新されたタイトル" } }, as: :turbo_stream

        expect(subtask.reload.title).to eq "更新されたタイトル"
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include('turbo-stream action="replace" target="subtasks_area"')
      end
    end
  end

  describe "DELETE /tasks/:task_id/subtasks/:id" do
    it "サブタスクを削除し、Turbo Streamで削除命令を返すこと (AC-4)" do
      expect {
        delete task_subtask_path(parent_task, subtask), as: :turbo_stream
      }.to change(parent_task.children, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include('turbo-stream action="replace" target="subtasks_area"')
    end
  end

  describe "PATCH /tasks/:task_id/subtasks/:id (期限の更新テスト)" do
    it "有効な期限（due_at）を設定・更新できること (AC-1, AC-4)" do
      future_due = 2.hours.from_now.change(usec: 0) # 秒以下のズレを防ぐため
      patch task_subtask_path(parent_task, subtask), params: { task: { due_at: future_due.iso8601 } }, as: :turbo_stream

      expect(subtask.reload.due_at.to_i).to eq(future_due.to_i)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
    end

    context "無効なパラメータ（過去の日時や親の期限超え）の場合 (AC-3)" do
      it "過去の日時を設定しようとした場合、更新されずにエラーを返すこと" do
        patch task_subtask_path(parent_task, subtask), params: { task: { due_at: 1.hour.ago.iso8601 } }, as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include("現在より前の日時を設定できません")
      end

      it "親タスクの期限を超える日時を設定しようとした場合、更新されずにエラーを返すこと" do
        patch task_subtask_path(parent_task, subtask), params: { task: { due_at: 2.days.from_now.iso8601 } }, as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include("親タスクの期限を超える日時を設定できません")
      end
    end
  end

  describe "PATCH /tasks/:task_id/subtasks/:id/toggle_status" do
    it "未完了のタスクを完了状態にし、Turbo Streamで置換命令を返すこと" do
      expect(subtask).to be_todo

      patch toggle_status_task_subtask_path(parent_task, subtask), as: :turbo_stream

      expect(subtask.reload).to be_done
      expect(subtask.completed_at).not_to be_nil
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      # サブタスク自身の更新と、親タスクの進捗バーの更新を両方確認
      expect(response.body).to include(%(turbo-stream action="replace" target="task_#{subtask.id}"))
      expect(response.body).to include(%(turbo-stream action="replace" target="task_progress_#{parent_task.id}"))
    end

    it "完了済みのタスクを未完了状態に戻し、Turbo Streamで置換命令を返すこと" do
      subtask.update!(status: :done, completed_at: Time.current)

      patch toggle_status_task_subtask_path(parent_task, subtask), as: :turbo_stream

      expect(subtask.reload).to be_todo
      expect(subtask.completed_at).to be_nil
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include(%(turbo-stream action="replace" target="task_#{subtask.id}"))
      expect(response.body).to include(%(turbo-stream action="replace" target="task_progress_#{parent_task.id}"))
    end
  end

  # サブタスクのカードは <li> そのもの（id="task_<id>"）で、Turbo Stream はこの <li> を差し替える。
  # <ol> の直下に <turbo-frame> を挟まない
  describe "サブタスクのマークアップ" do
    def stream_template(target)
      Nokogiri::HTML(response.body).at_css(%(turbo-stream[target="#{target}"] template))
    end

    it "S-4 の一覧で、<ol> の直下がサブタスクの <li> になる" do
      get task_path(parent_task)

      list = Nokogiri::HTML(response.body).at_css("ol#subtasks-list")
      expect(list.element_children.map { [ it.name, it["id"] ] }).to eq [ [ "li", "task_#{subtask.id}" ] ]
      expect(response.body).not_to include("<turbo-frame")
    end

    it "完了の切り替え・キャンセル（show）・編集で、差し替える内容が <li id=\"task_<id>\"> になる" do
      patch toggle_status_task_subtask_path(parent_task, subtask), as: :turbo_stream
      toggled = Nokogiri::HTML(stream_template("task_#{subtask.id}").inner_html)

      get task_subtask_path(parent_task, subtask), as: :turbo_stream
      shown = Nokogiri::HTML(stream_template("task_#{subtask.id}").inner_html)

      get edit_task_subtask_path(parent_task, subtask), as: :turbo_stream
      editing = Nokogiri::HTML(stream_template("task_#{subtask.id}").inner_html)

      [ toggled, shown, editing ].each do |doc|
        root = doc.at_css("body").element_children
        expect(root.map { [ it.name, it["id"] ] }).to eq [ [ "li", "task_#{subtask.id}" ] ]
      end
    end
  end

  # 他人のサブタスクの URL は 404（親タスクもサブタスクも Current.user のものからだけ探す）
  describe "他人のサブタスク" do
    let(:other) { create(:user) }
    let(:other_task) { create(:task, user: other, due_at: 1.day.from_now) }
    let!(:other_subtask) { create(:task, :subtask, parent: other_task, title: "他人のサブタスク") }

    {
      "詳細（キャンセル）" => ->(t, st) { [ :get, task_subtask_path(t, st) ] },
      "編集フォーム" => ->(t, st) { [ :get, edit_task_subtask_path(t, st) ] },
      "更新" => ->(t, st) { [ :patch, task_subtask_path(t, st), { task: { title: "書き換え" } } ] },
      "削除" => ->(t, st) { [ :delete, task_subtask_path(t, st) ] },
      "完了の切り替え" => ->(t, st) { [ :patch, toggle_status_task_subtask_path(t, st) ] }
    }.each do |name, request_for|
      it "#{name}: 他人の親タスク配下の URL は 404 で、サブタスクは変わらない" do
        verb, path, params = instance_exec(other_task, other_subtask, &request_for)
        send(verb, path, params:, as: :turbo_stream)

        expect(response).to have_http_status(:not_found)
        expect(other_subtask.reload).to have_attributes(title: "他人のサブタスク", status: "todo")
      end

      it "#{name}: 自分の親タスクの URL に他人のサブタスクの id を入れても 404" do
        verb, path, params = instance_exec(parent_task, other_subtask, &request_for)
        send(verb, path, params:, as: :turbo_stream)

        expect(response).to have_http_status(:not_found)
        expect(other_subtask.reload).to have_attributes(title: "他人のサブタスク", status: "todo")
      end
    end

    it "他人の親タスクのサブタスク一覧・追加は 404" do
      get task_subtasks_path(other_task, filter: "all"), as: :turbo_stream
      expect(response).to have_http_status(:not_found)

      expect {
        post task_subtasks_path(other_task), params: { task: { title: "紛れ込み" } }, as: :turbo_stream
      }.not_to change(Task, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
