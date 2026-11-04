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
        expect(response.body).to include('turbo-stream action="replace" target="new_subtask_form"')
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
        expect(response.body).to include(%(turbo-stream action="replace" target="task_#{subtask.id}"))
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
      expect(response.body).to include(%(turbo-stream action="remove" target="task_#{subtask.id}"))
    end
  end
end
