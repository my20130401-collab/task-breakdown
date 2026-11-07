require "rails_helper"

# 画面モックの撤去: 旧モックの URL は存在せず、どの経路でも誰としてもログインできない
RSpec.describe "撤去した画面モックのルート" do
  let!(:user) do
    User.create!(
      name: "既存ユーザー",
      email_address: "existing@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end

  [
    [ :post, "/login", { email_address: "anyone@example.com", password: "anything" } ],
    [ :post, "/signup", { email_address: "anyone@example.com", password: "anything" } ],
    [ :get, "/login", {} ],
    [ :get, "/signup", {} ],
    [ :get, "/tasks/sample", {} ]
  ].each do |method, path, params|
    describe "#{method.upcase} #{path}" do
      it "ルーティングされず 404 になる" do
        expect { Rails.application.routes.recognize_path(path, method:) }
          .to raise_error(ActionController::RoutingError)

        public_send(method, path, params:)

        expect(response).to have_http_status(:not_found)
      end

      it "セッションを発行せず、続く GET /tasks はログイン画面へ移る" do
        expect { public_send(method, path, params:) }.not_to change(Session, :count)
        expect(cookies[:session_id]).to be_blank

        get tasks_path

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  it "ログイン済みでも /tasks/sample は 404 になる（タスク詳細の id として扱わない）" do
    post session_path, params: { email_address: user.email_address, password: "password123" }

    get "/tasks/sample"

    expect(response).to have_http_status(:not_found)
  end

  it "MocksController が存在しない" do
    expect(defined?(MocksController)).to be_nil
  end
end
