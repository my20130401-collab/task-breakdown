require "net/http"
require "json"
require "uri"

module Llm
  # OpenAI API を利用してタスク分解を実行するクライアントクラス
  class OpenAiClient
    OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_MODEL", "gpt-5-mini"))
      raise ArgumentError, "OPENAI_API_KEY が設定されていません" if api_key.blank?

      @api_key = api_key
      @model = model
    end

    # プロンプトを OpenAI API に送信し、結果を Hash で返却する
    # @param prompt [String]
    # @return [Hash]
    def decompose(prompt:, **_options)
      uri = URI.parse(OPENAI_API_URL)
      request = Net::HTTP::Post.new(uri).tap do |req|
        req["Authorization"] = "Bearer #{@api_key}"
        req["Content-Type"] = "application/json"
        req.body = JSON.generate({
          model: @model,
          messages: [{ role: "user", content: prompt }]
        })
      end

      # 分解処理の完了待ちを考慮し、読み込みタイムアウトは 60 秒に設定
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 60
        http.request(request)
      end

      handle_response(response)
    end

    private

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        body = JSON.parse(response.body, symbolize_names: true)
        content = body.dig(:choices, 0, :message, :content)
        JSON.parse(content, symbolize_names: true)
      else
        raise "OpenAI API 通信エラー: HTTP #{response.code} - #{response.body}"
      end
    end
  end
end
