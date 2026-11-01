class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tasks, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true, length: { maximum: 50 }
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :terms_accepted_at, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true
end
