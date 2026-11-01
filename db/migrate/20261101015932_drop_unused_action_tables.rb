class DropUnusedActionTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :action_text_rich_texts, if_exists: true
    drop_table :action_mailbox_inbound_emails, if_exists: true
    drop_table :active_storage_variant_records, if_exists: true
    drop_table :active_storage_attachments, if_exists: true
    drop_table :active_storage_blobs, if_exists: true
  end

  def down
  end
end
