# 横断検査（spec/requests/pages_*_spec.rb）で巡回する画面の URL と、検査用の HTML の読み方。
# 画面や状態を足したら PATHS にも足す（巡回から漏れた画面は検査されない）
module Pages
  # ログイン前の画面（S-1 ログイン, S-2 会員登録, S-6 利用規約, S-7 プライバシーポリシー）
  PATHS = %w[
    /session/new
    /registration/new
    /terms
    /privacy
  ].freeze

  # 外部への参照として許すホスト（Web フォント）。<a href> / <form action> には外部 URL を置かない
  ALLOWED_EXTERNAL_HOSTS = %w[fonts.googleapis.com fonts.gstatic.com].freeze

  # デザイントークンを使わずに書いた色・文字サイズ（16 進の色、rgba()、10px 未満の文字）
  BANNED_VALUES = /#\h{6}\b|rgba\(|text-\[9px\]/

  # 描画された HTML を読む。<template> は除く。
  # Nokogiri は template の中身も通常の要素として読むため、そのままだとひな形の id や属性が
  # 画面上の要素として数えられてしまう
  def pages_document(body = response.body)
    Nokogiri::HTML(body).tap { |doc| doc.css("template").each(&:remove) }
  end

  # 違反の報告に使う要素の名前（aria-label → 文字列 → id の順）
  def element_name(node)
    node["aria-label"].presence || node.text.squish.presence || node["id"].presence || node.name
  end
end

RSpec.configure do |config|
  config.include Pages, type: :request
end
