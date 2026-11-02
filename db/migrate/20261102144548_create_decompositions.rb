class CreateDecompositions < ActiveRecord::Migration[8.1]
  def change
    create_table :decompositions do |t|
      t.references :task, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :granularity, null: false, default: 0
      t.string :model
      t.jsonb :request_payload, null: false, default: {}
      t.jsonb :response_payload
      t.text :error_message

      t.timestamps
    end
  end
end
