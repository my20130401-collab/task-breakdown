class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tasks, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # 会員登録フォームの「利用規約とプライバシーポリシーに同意する」（DB には持たず、同意した日時を terms_accepted_at に残す）。
  # 値があるとき（nil 以外）だけ検証する。会員登録ではコントローラが未送信を未チェック（"0"）として渡す。
  # 値なし（nil）で作るとき（シード・テスト等）は terms_accepted_at の必須チェックで止まる
  attribute :terms_of_service, :boolean
  validates :terms_of_service, acceptance: { accept: true }
  before_validation :record_terms_acceptance, on: :create

  validates :name, presence: true, length: { maximum: 50 }
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  # 同意しなかった（terms_of_service が false）ときは terms_of_service のエラーだけを出す（同じ理由のエラーを重ねない）
  validates :terms_accepted_at, presence: true, unless: -> { terms_of_service == false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  private

  def record_terms_acceptance
    self.terms_accepted_at ||= Time.current if terms_of_service
  end
end
