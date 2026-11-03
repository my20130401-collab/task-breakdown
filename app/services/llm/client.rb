module Llm
  # 環境変数や設定値に応じて適切な LLM クライアントを生成するファクトリクラス
  class Client
    class << self
      # 指定されたクライアント識別子、または環境変数からクライアントインスタンスを生成する
      # @param client_type [String, Symbol, nil] "openai" または "fake"（未指定時は環境変数から自動判定）
      # @return [Llm::OpenAiClient, Llm::FakeClient]
      def build(client_type = nil)
        type = client_type&.to_s || determine_client_type

        case type
        when "openai"
          Llm::OpenAiClient.new
        when "fake"
          Llm::FakeClient.new
        else
          raise ArgumentError, "未対応の LLM クライアント種別です: #{type}"
        end
      end

      private

      # 環境変数から利用すべきクライアント種別（openai / fake）を判定する
      # ENV['LLM_CLIENT'] を最優先し、未設定時は OPENAI_API_KEY の有無で判定する
      def determine_client_type
        return ENV["LLM_CLIENT"] if ENV["LLM_CLIENT"].present?

        ENV["OPENAI_API_KEY"].present? ? "openai" : "fake"
      end
    end
  end
end
