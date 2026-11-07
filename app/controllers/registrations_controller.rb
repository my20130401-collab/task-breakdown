class RegistrationsController < ApplicationController
  layout "auth"

  # ログイン済みなら root_path へリダイレクト
  redirect_if_authenticated only: %i[new create]
  allow_unauthenticated_access only: %i[new create]
  # ログインと同じ回数制限（同じ IP から 3 分で 10 回まで）。アカウントの大量作成を防ぐ
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "時間をおいて再度お試しください。" }

  def new
    @user = User.new
  end

  def create
    # 利用規約への同意（terms_of_service）はモデルが検証し、同意した日時を terms_accepted_at に記録する
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user # Rails 8標準のセッション開始メソッド
      redirect_to root_path, notice: "アカウントを登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    # 同意のチェックボックスが送られなかったときも、未チェックとして扱う
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :terms_of_service)
          .with_defaults(terms_of_service: "0")
  end
end
