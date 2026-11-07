# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::Client do
  # ----------------------------------------------------------------
  # 1. ファクトリメソッド（Llm::Client.build）の振り分けテスト
  # ----------------------------------------------------------------
  describe ".build" do
    # 環境変数 LLM_CLIENT に応じた切り替え
    context "環境変数 LLM_CLIENT が明示的に設定されている場合" do
      it "LLM_CLIENT=fake のときは Llm::FakeClient を返すこと" do
        client = described_class.build("fake")
        expect(client).to be_a(Llm::FakeClient)
      end

      it "LLM_CLIENT=openai のときは Llm::OpenAiClient を返すこと" do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("dummy_api_key")

        client = described_class.build("openai")
        expect(client).to be_a(Llm::OpenAiClient)
      end
    end

    # 環境変数未設定時の自動判定（フォールバック）
    context "環境変数 LLM_CLIENT が未設定の場合" do
      it "OPENAI_API_KEY が存在する場合は Llm::OpenAiClient を返すこと" do
        allow(ENV).to receive(:[]).with("LLM_CLIENT").and_return(nil)
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("dummy_api_key")

        expect(described_class.build).to be_a(Llm::OpenAiClient)
      end

      it "OPENAI_API_KEY が存在しない場合は安全のため Llm::FakeClient を返すこと" do
        allow(ENV).to receive(:[]).with("LLM_CLIENT").and_return(nil)
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

        expect(described_class.build).to be_a(Llm::FakeClient)
      end
    end

    # 未知のクライアント種別に対するガード
    context "未対応の種別が渡された場合" do
      it "ArgumentError が発生すること" do
        expect { described_class.build("unknown") }.to raise_error(ArgumentError, /未対応の LLM クライアント種別/)
      end
    end
  end

  # ----------------------------------------------------------------
  # 2. 練習用クライアント（Llm::FakeClient）の動作テスト
  # ----------------------------------------------------------------
  describe "Llm::FakeClient" do
    subject(:client) { Llm::FakeClient.new }

    it "外部通信を行わず、指定の固定サブタスクデータを返すこと" do
      result = client.decompose(prompt: "テストプロンプト")

      expect(result).to have_key(:subtasks)
      expect(result[:subtasks].size).to eq(3)
      expect(result[:subtasks].first[:title]).to eq("仕入れ先に見積もりを依頼する")
    end
  end

  # ----------------------------------------------------------------
  # 3. 本番通信用クライアント（Llm::OpenAiClient）の動作テスト
  # ----------------------------------------------------------------
  describe "Llm::OpenAiClient" do
    subject(:client) { Llm::OpenAiClient.new(api_key: "test_key") }

    let(:dummy_response_body) do
      {
        choices: [
          {
            message: {
              content: {
                subtasks: [
                  { title: "タスクA", description: "説明A", kind: "basic", estimated_minutes: 10, due_at: nil }
                ]
              }.to_json
            }
          }
        ]
      }.to_json
    end

    before do
      # WebMock を使って OpenAI API への通信を遮断し、Structured Outputs のリクエスト構造を検証する
      stub_request(:post, Llm::OpenAiClient::OPENAI_API_URL)
        .with(
          headers: {
            "Authorization" => "Bearer test_key",
            "Content-Type" => "application/json"
          }
        ) do |request|
          payload = JSON.parse(request.body)
          payload["model"] == "gpt-5-mini" &&
            payload["messages"] == [ { "role" => "user", "content" => "タスクを分解してください" } ] &&
            payload.dig("response_format", "type") == "json_schema" &&
            payload.dig("response_format", "json_schema", "strict") == true &&
            payload.dig("response_format", "json_schema", "schema") == TaskDecomposer::Prompt.response_schema.deep_stringify_keys
        end
        .to_return(
          status: 200,
          body: dummy_response_body,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "Structured Outputs のスキーマを含めてリクエストを送り、パース済みのレスポンスを返すこと" do
      result = client.decompose(prompt: "タスクを分解してください")

      expect(result[:subtasks].first[:title]).to eq("タスクA")
    end

    it "API キーが未設定の場合は初期化時にエラーになること" do
      expect {
        Llm::OpenAiClient.new(api_key: nil)
      }.to raise_error(ArgumentError, "OPENAI_API_KEY が設定されていません")
    end
  end
end
