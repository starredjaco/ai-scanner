class CreateDataSyncVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :data_sync_versions do |t|
      t.string :sync_type, null: false
      t.string :file_path, null: false
      t.string :file_checksum, null: false
      t.integer :record_count
      t.datetime :synced_at
      t.json :metadata

      t.timestamps
    end

    add_index :data_sync_versions, [ :sync_type, :file_checksum ], unique: true
    add_index :data_sync_versions, :sync_type
  end
end
