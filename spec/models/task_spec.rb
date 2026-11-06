require "rails_helper"

RSpec.describe Task do
  # ----------------------------------------------------------------
  # 1. バリデーション（保存ルール）のテスト
  # ----------------------------------------------------------------
  describe "バリデーション" do
    let(:user) { create(:user) }

    it "有効な属性を持つ場合は保存できること" do
      # 正常系：すべての値が正しければ問題なく保存できる
      task = build(:task, user: user)
      expect(task).to be_valid
    end

    # タスク名の文字数・空欄チェック（AC-2）
    describe "title" do
      it "空欄の場合は無効であること (AC-2)" do
        # タイトルが空っぽ（""）だと保存できずにエラーになる
        task = build(:task, user: user, title: "")
        expect(task).not_to be_valid
        expect(task.errors[:title]).to be_present
      end

      it "200文字の場合は有効であること" do
        # ちょうど上限の200文字なら合格
        task = build(:task, user: user, title: "a" * 200)
        expect(task).to be_valid
      end

      it "201文字以上の場合は無効であること (AC-2)" do
        # 201文字以上になると保存できずにエラーになる
        task = build(:task, user: user, title: "a" * 201)
        expect(task).not_to be_valid
        expect(task.errors[:title]).to be_present
      end
    end

    # 締め切り日時の過去日チェック（AC-3）
    describe "due_at" do
      it "過去の日時の場合は無効であること (AC-3)" do
        # 1分前（過去の日時）を指定した場合はエラーメッセージ付きで弾かれる
        task = build(:task, user: user, due_at: 1.minute.ago)
        expect(task).not_to be_valid
        expect(task.errors[:due_at]).to include("は現在より前の日時を設定できません")
      end

      it "未来の日時の場合は有効であること" do
        # 1時間後（未来の日時）なら合格
        task = build(:task, user: user, due_at: 1.hour.from_now)
        expect(task).to be_valid
      end

      it "期限が未設定（nil）の場合も有効であること" do
        # 「期限なし」のタスクも作れる仕様のため、空っぽ（nil）でも合格
        task = build(:task, user: user, due_at: nil)
        expect(task).to be_valid
      end

      it "現在の時刻と同じ分を指定した場合は有効であること" do
        # 現在時刻と同じ分を指定した場合は、過去日ではないため合格
        task = build(:task, user: user, due_at: Time.current.beginning_of_minute)
        expect(task).to be_valid
      end

      it "親タスクの期限を超える日時の場合は無効であること (AC-3)" do
        # 親タスクの期限が3日後の場合、4日後は設定できずにエラーになる
        parent_task = create(:task, user: user, due_at: 3.days.from_now)
        task = build(:task, user: user, parent: parent_task, due_at: 4.days.from_now)

        expect(task).not_to be_valid
        expect(task.errors[:due_at]).to include("は親タスクの期限を超える日時を設定できません")
      end
    end

    # ユーザーとの紐付けチェック（AC-4 / 認可の基盤）
    describe "user" do
      it "ユーザーに紐付いていない場合は無効であること (AC-4)" do
        # 持ち主（user_id）が存在しない迷子タスクは作成できない
        task = build(:task, user: nil)
        expect(task).not_to be_valid
        expect(task.errors[:user]).to be_present
      end
    end
  end

    # 親子タスクの所有者一致チェック（Issue #81）
    describe "parent_id" do
      let(:user) { create(:user) }
      let(:user_b) { create(:user) }
      let(:parent_task) { create(:task, user: user) }

      it "親タスクと子タスクの所有者が一致する場合は有効であること" do
        child_task = build(:task, user: user, parent: parent_task)
        expect(child_task).to be_valid
      end

      it "親タスクと子タスクの所有者が一致しない場合は無効であること" do
        child_task = build(:task, user: user_b, parent: parent_task)
        expect(child_task).not_to be_valid
        expect(child_task.errors[:parent_id]).to include("は同じユーザーのタスクを指定してください")
      end
    end

  # ----------------------------------------------------------------
  # 2. アソシエーション（関連付け）のテスト
  # ----------------------------------------------------------------
  describe "アソシエーション" do
    let(:user) { create(:user) }

    it "自己参照で親タスクと子タスク（サブタスク）の関連を持てること" do
      # 親タスクから子どもたち（children）が見え、子タスクから親（parent）が見えること
      parent_task = create(:task, user: user)
      child_task = create(:task, user: user, parent: parent_task)

      expect(child_task.parent).to eq(parent_task)
      expect(parent_task.children).to include(child_task)
    end

    it "親タスクが削除されたら子タスクも一緒に削除されること" do
      # 親タスクを削除した際、連動してサブタスクもデータベースから削除される（dependent: :destroy）
      parent_task = create(:task, user: user)
      create(:task, user: user, parent: parent_task)

      expect { parent_task.destroy }.to change(described_class, :count).by(-2)
    end
  end

  # ----------------------------------------------------------------
  # 3. 初期値（Enum・デフォルト値）のテスト
  # ----------------------------------------------------------------
  describe "初期値（Enum）" do
    let(:task) { build(:task) }

    it "デフォルトで basic / todo / manual であること" do
      # タスク作成直後は「基本タスク」「未完了」「手動作成」になっている
      expect(task).to be_basic
      expect(task).to be_todo
      expect(task).to be_manual
    end
  end

  # ----------------------------------------------------------------
  # 4. 完了・未完了の切り替えメソッド（complete! / uncomplete!）
  # ----------------------------------------------------------------
  describe "完了・未完了の切り替え" do
    let(:user) { create(:user) }
    let(:task) { create(:task, user: user, status: :todo) }

    describe "#complete!" do
      it "ステータスが done になり、completed_at に現在時刻がセットされること" do
        # 完了メソッドを呼ぶと、ステータスが done に変わり完了日時が記録される
        task.complete!
        expect(task.reload).to be_done
        expect(task.completed_at).to be_present
      end
    end

    describe "#uncomplete!" do
      it "ステータスが todo に戻り、completed_at が nil になること" do
        # 一度完了させた後、未完了に戻すと todo に戻り完了日時がクリアされる
        task.complete!
        task.uncomplete!
        expect(task.reload).to be_todo
        expect(task.completed_at).to be_nil
      end
    end
  end

  # ----------------------------------------------------------------
  # 5. サブタスクとの完了状態の自動同期（sync_parent_status コールバック）
  # ----------------------------------------------------------------
  describe "親タスクとの完了自動同期（sync_parent_status）" do
    let(:user) { create(:user) }
    let(:parent_task) { create(:task, user: user, status: :todo) }

    context "すべてのサブタスクが完了になった場合" do
      it "親タスクが自動的に完了（done）になること" do
        # 2つの子タスク（サブタスク）を作成
        sub1 = create(:task, user: user, parent: parent_task, status: :todo)
        sub2 = create(:task, user: user, parent: parent_task, status: :todo)

        expect(parent_task.reload).to be_todo

        # 1つ目だけ完了しても、まだ親タスクは未完了（todo）のまま
        sub1.complete!
        expect(parent_task.reload).to be_todo

        # 2つ目（すべて）が完了すると、連動コールバックで親タスクも自動的に done になる
        sub2.complete!
        expect(parent_task.reload).to be_done
        expect(parent_task.completed_at).to be_present
      end
    end

    context "完了していた親タスクのサブタスクが1つでも未完了に戻った場合" do
      it "親タスクが自動的に未完了（todo）に戻ること" do
        # 初めから全完了状態のサブタスクを作成
        sub1 = create(:task, user: user, parent: parent_task, status: :done)
        sub2 = create(:task, user: user, parent: parent_task, status: :done)

        expect(parent_task.reload).to be_done

        # 1つのサブタスクを未完了に戻すと、連動して親タスクも todo に戻る
        sub1.uncomplete!
        expect(parent_task.reload).to be_todo
        expect(parent_task.completed_at).to be_nil
      end
    end

    context "未完了のサブタスクを削除した場合" do
      it "残りのサブタスクがすべて完了済みであれば親タスクが自動的に done になること" do
        # 完了1件・未完了1件の子タスクを作成（この時点では親は todo）
        sub1 = create(:task, user: user, parent: parent_task, status: :done)
        sub2 = create(:task, user: user, parent: parent_task, status: :todo)

        expect(parent_task.reload).to be_todo

        # 未完了の sub2 を削除すると、残りが done だけになるため親も連動して done に変わる
        sub2.destroy
        expect(parent_task.reload).to be_done
      end
    end

    context "サブタスクが削除されて0件になった場合" do
      it "親タスクのステータスは変化しないこと" do
        # 子タスクを作成
        sub = create(:task, user: user, parent: parent_task, status: :todo)

        # 唯一の子タスクを削除して子が0件になっても、親のステータスは勝手に変わらず維持される
        sub.destroy
        expect(parent_task.reload).to be_todo
      end
    end
  end
end
