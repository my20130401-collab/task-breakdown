# 利用規約（S-6）・プライバシーポリシー（S-7）。会員登録前に読めるよう、ログインの有無を問わず表示する
class PagesController < ApplicationController
  layout "auth"

  allow_unauthenticated_access only: %i[terms privacy]

  def terms
  end

  def privacy
  end
end
