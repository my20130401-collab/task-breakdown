class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      # 外部キー（誰のタスクか）
      t.references :user, null: false, foreign_key: true

      # 自己参照（親タスクのID。NULLなら親タスク）
      t.references :parent, foreign_key: { to_table: :tasks }, index: true

      # タスク基本情報
      t.string :title, null: false, limit: 200
      t.text :description
      t.integer :kind, null: false, default: 0
      t.datetime :due_at
      t.integer :status, null: false, default: 0
      t.datetime :completed_at
      t.integer :position, null: false, default: 0
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    # docs/data-model.md で指定されたインデックス
    add_index :tasks, [ :user_id, :status, :due_at ]
  end
end
