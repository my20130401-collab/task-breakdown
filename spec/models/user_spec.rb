require "rails_helper"

RSpec.describe User do
  describe "バリデーション" do
    let(:user) { build(:user) }

    # FactoryBot で生成したデフォルト値が有効であることの確認
    it "有効な属性を持つ場合は有効であること" do
      expect(user).to be_valid
    end

    # S-2 会員登録: お名前入力の検証（必須・上限50文字）
    describe "お名前（name）" do
      it "必須であること" do
        user.name = ""
        expect(user).not_to be_valid
        expect(user.errors[:name]).to be_present
      end

      it "50文字以内であること" do
        user.name = "a" * 50
        expect(user).to be_valid

        user.name = "a" * 51
        expect(user).not_to be_valid
        expect(user.errors[:name]).to be_present
      end
    end

    # S-2 会員登録: 利用規約・プライバシーポリシー同意日時の検証（必須）
    describe "利用規約への同意（terms_accepted_at）" do
      it "必須であること" do
        user.terms_accepted_at = nil
        expect(user).not_to be_valid
        expect(user.errors[:terms_accepted_at]).to be_present
      end
    end

    # S-2 会員登録: 「利用規約とプライバシーポリシーに同意する」のチェック（terms_of_service）
    describe "利用規約への同意のチェック（terms_of_service）" do
      let(:user) { build(:user, terms_accepted_at: nil) }

      it "チェックした（\"1\"）ときは、作成時に同意した日時を記録する" do
        travel_to(Time.zone.local(2026, 6, 20, 10, 0))
        user.terms_of_service = "1"

        expect(user.save).to be true
        expect(user.terms_accepted_at).to eq Time.current
      end

      it "チェックしない（\"0\"）ときは無効で、エラーは terms_of_service の 1 件だけ" do
        user.terms_of_service = "0"

        expect(user).not_to be_valid
        expect(user.errors.full_messages).to eq [ "利用規約とプライバシーポリシーに同意してください" ]
      end
    end

    # S-2 会員登録: メールアドレスの検証（必須・一意性・形式・正規化）
    describe "メールアドレス（email_address）" do
      it "必須であること" do
        user.email_address = ""
        expect(user).not_to be_valid
        expect(user.errors[:email_address]).to be_present
      end

      it "一意（ユニーク）であること" do
        create(:user, email_address: "unique@example.com")
        duplicate_user = build(:user, email_address: "unique@example.com")
        expect(duplicate_user).not_to be_valid
        expect(duplicate_user.errors[:email_address]).to be_present
      end

      it "正しい形式であること" do
        valid_addresses = %w[user@example.com USER@foo.COM A_US-ER@foo.bar.org first.last@foo.jp]
        valid_addresses.each do |valid_address|
          user.email_address = valid_address
          expect(user).to be_valid
        end
      end

      it "不正な形式は無効であること" do
        invalid_addresses = %w[user@example,com user_at_foo.org user.name@example. foo@bar_baz.com]
        invalid_addresses.each do |invalid_address|
          user.email_address = invalid_address
          expect(user).not_to be_valid
          expect(user.errors[:email_address]).to be_present
        end
      end

      it "保存時に前後の空白が除去され、小文字化されること" do
        user.email_address = "  TEST@EXAMPLE.COM  "
        user.save!
        expect(user.reload.email_address).to eq "test@example.com"
      end
    end

    # S-2 会員登録: パスワード文字数の検証（8文字以上）
    describe "パスワード（password）" do
      it "8文字以上であること" do
        user.password = "1234567"
        user.password_confirmation = "1234567"
        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present

        user.password = "12345678"
        user.password_confirmation = "12345678"
        expect(user).to be_valid
      end
    end
  end
end
