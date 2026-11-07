require "rails_helper"

# トークン化の回帰検査。ビューに直書きしていた色・影の値が、ビルド後の CSS にトークン経由で残っていることを確かめる。
# 事前に `bin/rails tailwindcss:build` が必要（CI の test ジョブはビルド後に rspec を実行する）。
RSpec.describe "デザイントークン" do
  let(:css) do
    path = Rails.root.join("app/assets/builds/tailwind.css")
    raise "#{path} がありません。先に bin/rails tailwindcss:build を実行してください" unless path.exist?

    path.read.gsub(/\s+/, "")
  end

  # 圧縮の有無で表記が変わる（0.213 → .213、rgba(...) → 8 桁 16 進）ため両方を許容する
  {
    "--color-line-strong" => [ "#bbbeba" ],
    "--color-line-dashed" => [ "#cfd4cc" ],
    "--color-avatar" => [ "#a7bba4" ],
    "--color-brand" => [ "#426349" ],
    "--color-danger" => [ "oklch(50.5%0.21327.518)", "oklch(50.5%.21327.518)" ], # 旧 text-red-700
    "--color-danger-dot" => [ "oklch(57.7%0.24527.325)", "oklch(57.7%.24527.325)" ], # 旧 bg-red-600
    "--color-danger-soft" => [ "#fbecea" ], # エラー表示の背景（旧 bg-red-50）
    "--text-2xs" => [ "10px" ]
  }.each do |token, values|
    it "#{token} が置換前と同じ値を持つ" do
      expect(values.map { "#{token}:#{it}" }).to include(satisfy { css.include?(it) })
    end
  end

  {
    "shadow-card" => [ "08px24px-12px", %w[rgba(32,36,33,0.18) #2024212e] ],
    "shadow-float" => [ "012px40px-12px", %w[rgba(32,36,33,0.12) #2024211f] ]
  }.each do |name, (geometry, colors)|
    it "#{name} が置換前と同じ影を生成する" do
      candidates = colors.map { "#{geometry}var(--tw-shadow-color,#{it})" }

      expect(candidates).to include(satisfy { css.include?(it) })
    end
  end

  it "ビューで使うトークンのユーティリティが生成されている" do
    %w[.text-2xs .text-danger .bg-danger-dot .bg-danger-soft .border-line-strong .border-line-dashed .bg-avatar
       .shadow-float .accent-brand].each do |selector|
      expect(css).to include("#{selector}{"), "#{selector} が CSS にありません"
    end
    expect(css).to include("hover\\:shadow-card:hover")
  end

  # 白地・canvas 地で非テキストのコントラスト 3:1 以上（#66866b は白に対して約 4.0:1）
  it "リンク・ボタンのキーボードフォーカスに ring-brand-dot を表示する" do
    expect(css).to match(/a\[href\],button.*?:focus-visible\{[^}]*var\(--color-brand-dot\)/)
  end
end
