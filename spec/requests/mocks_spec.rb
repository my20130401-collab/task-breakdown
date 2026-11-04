# frozen_string_literal: true

require "rails_helper"

RSpec.describe "画面モック" do
  def html
    Nokogiri::HTML(response.body)
  end

  # S-4, S-5 は本実装へ移行したため除外
  {
    "/signup" => "アカウントを作成する",
    "/login" => "おかえりなさい"
  }.each do |path, text|
    it "#{path} が表示できる" do
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(text)
    end
  end

  describe "共通 head" do
    it "画面ごとのタイトルを表示する" do
      get "/login"

      expect(html.at_css("head title").text).to eq "ログイン | Tasklet"
    end

    it "共通の head 要素（viewport, icon）を持つ" do
      get "/login"

      expect(html.css("head meta[name='viewport']")).to be_present
      expect(html.css("head link[rel='icon']")).to be_present
    end
  end
end
