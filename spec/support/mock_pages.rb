# 横断検査（spec/requests/mock_*_spec.rb）で巡回する画面モックの URL と、検査用の HTML の読み方。
module MockPages
  # 全画面・全状態。S-4 は分解中・分解完了・分解失敗と全完了（S-5 は本実装へ移行したため除外）
  PATHS = %w[
    /tasks/sample
    /tasks/sample?status=decomposing
    /tasks/sample?status=failed
    /tasks/sample?all_done=1
    /signup
    /login
    /terms
    /privacy
  ].freeze

  # 外部への参照として許すホスト（Web フォント）。<a href> / <form action> には外部 URL を置かない
  ALLOWED_EXTERNAL_HOSTS = %w[fonts.googleapis.com fonts.gstatic.com].freeze

  # デザイントークンを使わずに書いた色・文字サイズ（16 進の色、rgba()、10px 未満の文字）
  BANNED_VALUES = /#\h{6}\b|rgba\(|text-\[9px\]/

  # 描画された HTML を読む。<template>（S-4 の「タスクを追加」用カードのひな形）は除く。
  # Nokogiri は template の中身も通常の要素として読むため、そのままだと __NUMBER__ 入りの id や
  # contenteditable が画面上の要素として数えられてしまう（ひな形は subtasks_controller が番号を振って複製する）
  def mock_document(body = response.body)
    Nokogiri::HTML(body).tap { |doc| doc.css("template").each(&:remove) }
  end

  # 違反の報告に使う要素の名前（aria-label → 文字列 → id の順）
  def element_name(node)
    node["aria-label"].presence || node.text.squish.presence || node["id"].presence || node.name
  end
end

RSpec.configure do |config|
  config.include MockPages, type: :request
end
