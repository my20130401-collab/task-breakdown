require "rails_helper"

# 会員登録（S-2）の守り: ログインと同じ回数制限（3 分で 10 回）と、利用規約への同意（terms_of_service）の必須化
RSpec.describe "会員登録の回数制限と利用規約への同意" do
  let(:params) do
    { user: { name: "新入 一郎", email_address: "new@example.com", password: "password123",
              password_confirmation: "password123", terms_of_service: "1" } }
  end

  describe "利用規約への同意（terms_of_service）" do
    it "チェックして送ると登録し、同意した日時を記録する" do
      travel_to(Time.zone.local(2026, 6, 20, 10, 0))

      expect { post registration_path, params: }.to change(User, :count).by(1)
      expect(User.last.terms_accepted_at).to eq Time.current
    end

    it "未チェック（0）や未送信では登録せず、同意を求めるエラーを 1 件だけ出す" do
      [ params.deep_merge(user: { terms_of_service: "0" }), { user: params[:user].except(:terms_of_service) } ].each do |invalid|
        expect { post registration_path, params: invalid }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        messages = Nokogiri::HTML(response.body).css("[role='alert'] li").map { it.text.squish }
        expect(messages.grep(/利用規約/)).to eq [ "利用規約とプライバシーポリシーに同意してください" ]
      end
    end

    it "terms_of_service を許可済みのパラメータとして受け取る（Unpermitted parameter を出さない）" do
      unpermitted = []
      callback = ->(*, payload) { unpermitted.concat(payload[:keys]) }

      ActiveSupport::Notifications.subscribed(callback, "unpermitted_parameters.action_controller") do
        post registration_path, params:
      end

      expect(unpermitted).to be_empty
    end
  end

  # test 環境の cache_store は null_store で回数を数えないため、回数制限が使うストアだけメモリに差し替える
  shared_context "回数を数えるストア" do
    let(:memory) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(controller_class.cache_store).to receive(:increment) { |*args, **opts| memory.increment(*args, **opts) }
    end
  end

  describe "会員登録の回数制限" do
    let(:controller_class) { RegistrationsController }

    include_context "回数を数えるストア"

    it "3 分で 10 回までは受け付け、11 回目は会員登録画面へ戻して時間をおくよう案内する" do
      10.times do |i|
        post registration_path, params: params.deep_merge(user: { email_address: "user#{i}@example.com" })
        expect(response).to redirect_to(root_path)
        delete session_path
      end

      expect { post registration_path, params: params.deep_merge(user: { email_address: "user10@example.com" }) }
        .not_to change(User, :count)
      expect(response).to redirect_to(new_registration_path)

      follow_redirect!
      expect(Nokogiri::HTML(response.body).at_css("[role='alert']").text.squish).to eq "時間をおいて再度お試しください。"
    end

    it "3 分たつと、また受け付ける" do
      travel_to(Time.zone.local(2026, 6, 20, 10, 0))
      11.times { post registration_path, params: params.deep_merge(user: { terms_of_service: "0" }) }
      expect(response).to redirect_to(new_registration_path)

      travel 3.minutes + 1.second
      post registration_path, params: params.deep_merge(user: { terms_of_service: "0" })

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "ログインの回数制限（会員登録と同じ設定）" do
    let(:controller_class) { SessionsController }
    let!(:user) { create(:user) }

    include_context "回数を数えるストア"

    it "3 分で 10 回までは受け付け、11 回目はログイン画面へ戻して時間をおくよう案内する" do
      10.times do
        post session_path, params: { email_address: user.email_address, password: "wrong-password" }
        expect(flash[:alert]).to eq "メールアドレスまたはパスワードが正しくありません。"
      end

      post session_path, params: { email_address: user.email_address, password: user.password }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq "時間をおいて再度お試しください。"
    end
  end
end
