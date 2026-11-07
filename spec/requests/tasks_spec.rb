require "rails_helper"

RSpec.describe "タスク管理（作成・更新・削除・認可）" do
  # テスト全体で使うログインユーザー
  let!(:user) do
    User.create!(
      name: "テストユーザー",
      email_address: "task-test@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end

  # ------------------------------------------------------------
  # 1. タスク作成画面の表示（GET /tasks/new または root_path）
  # ------------------------------------------------------------
  describe "GET /tasks/new" do
    context "未ログインの場合" do
      it "ログイン画面へリダイレクトされる" do
        get new_task_path

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "ログイン済みの場合" do
      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }
      end

      it "タスク作成画面が正常に表示され、作成フォームが存在する" do
        get new_task_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="/tasks"')
      end
    end
  end

  # ------------------------------------------------------------
  # 2. タスク作成の実行（POST /tasks）
  # ------------------------------------------------------------
  describe "POST /tasks" do
    context "未ログインの場合" do
      it "タスクは作成されず、ログイン画面へリダイレクトされる" do
        expect do
          post tasks_path, params: { task: { title: "未ログインタスク" } }
        end.not_to change(Task, :count)

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "ログイン済みの場合" do
      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }
      end

      context "有効なパラメータの場合" do
        let(:valid_params) do
          {
            task: {
              title: "新規事業の提案資料を作成する",
              due_at: 1.day.from_now.change(sec: 0)
            }
          }
        end

        it "タスクが作成され、ログイン中ユーザーに紐づいて詳細モックへリダイレクトされる" do
          expect do
            post tasks_path, params: valid_params
          end.to change(user.tasks, :count).by(1)

          created_task = user.tasks.last
          expect(created_task.title).to eq("新規事業の提案資料を作成する")

          expect(response).to redirect_to(task_path(created_task))
          expect(flash[:notice]).to eq(I18n.t("tasks.create.success"))
        end
      end

      context "無効なパラメータの場合（タイトルが空欄）" do
        let(:invalid_params) do
          {
            task: {
              title: "",
              due_at: 1.day.from_now
            }
          }
        end

        it "タスクは作成されず、422 Unprocessable Entity で作成画面が再描画される" do
          expect do
            post tasks_path, params: invalid_params
          end.not_to change(Task, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(flash.now[:alert]).to eq(I18n.t("tasks.create.failure"))
        end
      end

      context "無効なパラメータの場合（過去の期限日時）" do
        let(:past_params) do
          {
            task: {
              title: "過去日のタスク",
              due_at: 1.day.ago
            }
          }
        end

        it "タスクは作成されず、422 Unprocessable Entity が返る" do
          expect do
            post tasks_path, params: past_params
          end.not_to change(Task, :count)

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end

  # ------------------------------------------------------------
  # 3. マイタスク一覧画面の表示（GET /tasks）
  # ------------------------------------------------------------
  describe "GET /tasks" do
    context "未ログインの場合" do
      it "ログイン画面へリダイレクトされる" do
        get tasks_path

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "ログイン済みの場合" do
      let!(:other_user) do
        User.create!(
          name: "他ユーザー",
          email_address: "other@example.com",
          password: "password123",
          terms_accepted_at: Time.current
        )
      end

      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }

        user.tasks.create!(title: "自分の親タスク", due_at: 1.day.from_now)
        other_user.tasks.create!(title: "他人の親タスク", due_at: 1.day.from_now)
      end

      it "200 OK が返り、自分のタスクのみが表示され、他ユーザーのタスクは表示されない（AC-3）" do
        get tasks_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("自分の親タスク")
        expect(response.body).not_to include("他人の親タスク")
      end
    end
  end

  # ------------------------------------------------------------
  # 4. タスク編集画面の表示（GET /tasks/:id/edit）
  # ------------------------------------------------------------
  describe "GET /tasks/:id/edit" do
    let!(:task) { user.tasks.create!(title: "自分のタスク", due_at: 1.day.from_now) }

    context "未ログインの場合" do
      it "ログイン画面へリダイレクトされる" do
        get edit_task_path(task)

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "ログイン済みの場合" do
      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }
      end

      it "200 OK でタスク編集画面が表示され、フォームが存在する" do
        get edit_task_path(task)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("タスクの編集")
        expect(response.body).to include(task.title)
      end

      # AC-4: 他人のタスク認可制御
      it "他人のタスクの編集画面を開こうとすると 404 Not Found になる" do
        other_user = User.create!(
          name: "他ユーザー",
          email_address: "other_edit@example.com",
          password: "password123",
          terms_accepted_at: Time.current
        )
        other_task = other_user.tasks.create!(title: "他人のタスク")

        get edit_task_path(other_task)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ------------------------------------------------------------
  # 5. タスク更新の実行（PATCH /tasks/:id）
  # ------------------------------------------------------------
  describe "PATCH /tasks/:id" do
    let!(:task) { user.tasks.create!(title: "更新前のタスク", due_at: 1.day.from_now) }

    context "未ログインの場合" do
      it "更新されず、ログイン画面へリダイレクトされる" do
        patch task_path(task), params: { task: { title: "更新後タイトル" } }

        expect(task.reload.title).to eq("更新前のタスク")
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "ログイン済みの場合" do
      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }
      end

      context "有効なパラメータの場合" do
        let(:update_params) do
          {
            task: {
              title: "更新後のタスクタイトル",
              due_at: 2.days.from_now.change(sec: 0)
            }
          }
        end

        it "タスクが更新され、一覧画面へリダイレクトされる（AC-3）" do
          patch task_path(task), params: update_params

          expect(task.reload.title).to eq("更新後のタスクタイトル")
          expect(response).to redirect_to(tasks_path)
          expect(flash[:notice]).to eq(I18n.t("tasks.update.success"))
        end
      end

      context "無効なパラメータの場合（タイトルが空欄）" do
        it "タスクは更新されず、422 で編集画面が再描画される" do
          patch task_path(task), params: { task: { title: "" } }

          expect(task.reload.title).to eq("更新前のタスク")
          expect(response).to have_http_status(:unprocessable_content)
          expect(flash.now[:alert]).to eq(I18n.t("tasks.update.failure"))
        end
      end

      # AC-4: 他人のタスク認可制御
      it "他人のタスクを更新しようとすると 404 Not Found になる" do
        other_user = User.create!(
          name: "他ユーザー",
          email_address: "other_patch@example.com",
          password: "password123",
          terms_accepted_at: Time.current
        )
        other_task = other_user.tasks.create!(title: "他人のタスク")

        patch task_path(other_task), params: { task: { title: "書き換え攻撃" } }
        expect(response).to have_http_status(:not_found)
        expect(other_task.reload.title).to eq("他人のタスク")
      end
    end
  end

  # ------------------------------------------------------------
  # 6. タスク削除の実行（DELETE /tasks/:id）
  # ------------------------------------------------------------
  describe "DELETE /tasks/:id" do
    let!(:task) { user.tasks.create!(title: "削除予定のタスク", due_at: 1.day.from_now) }

    context "未ログインの場合" do
      it "削除されず、ログイン画面へリダイレクトされる" do
        expect do
          delete task_path(task)
        end.not_to change(Task, :count)

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "ログイン済みの場合" do
      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }
      end

      it "タスクが削除され、マイタスク一覧へリダイレクトされる（AC-3）" do
        expect do
          delete task_path(task)
        end.to change(user.tasks, :count).by(-1)

        expect(response).to redirect_to(tasks_path)
        expect(flash[:notice]).to eq(I18n.t("tasks.destroy.success"))
      end

      # AC-4: 他人のタスク認可制御
      it "他人のタスクを削除しようとすると 404 Not Found になる" do
        other_user = User.create!(
          name: "他ユーザー",
          email_address: "other_delete@example.com",
          password: "password123",
          terms_accepted_at: Time.current
        )
        other_task = other_user.tasks.create!(title: "他人のタスク")

        delete task_path(other_task)
        expect(response).to have_http_status(:not_found)
        expect(Task.exists?(other_task.id)).to be true
      end
    end
  end

  # ------------------------------------------------------------
  # タスク詳細の分解ステータス表示と再分解（GET /tasks/:id, POST /tasks/:id/redecompose）
  # ------------------------------------------------------------
  describe "分解ステータスと再分解" do
    let!(:task) { create(:task, user: user, title: "見積もりを作成する") }

    before do
      post session_path, params: { email_address: user.email_address, password: "password123" }
    end

    it "分解履歴もサブタスクもないタスクは、分解中のままにせず再分解ボタンを表示する" do
      get task_path(task)

      expect(response.body).to include("再分解する")
      expect(response.body).not_to include("data-skeleton")
    end

    it "分解に失敗したとき、エラーの詳細（API の応答）は画面に出さない" do
      create(:decomposition, :failed, task: task, error_message: "OpenAI API 通信エラー: HTTP 401 - secret body")

      get task_path(task)

      expect(response.body).to include("再分解する")
      expect(response.body).not_to include("secret body")
    end

    it "分解中に再分解しても、ジョブと履歴を重複して作らない" do
      create(:decomposition, task: task, status: :pending)

      expect {
        post redecompose_task_path(task)
      }.not_to have_enqueued_job(DecomposeTaskJob)
      expect(task.decompositions.count).to eq 1
      expect(response).to redirect_to(task_path(task))
    end
  end
end
