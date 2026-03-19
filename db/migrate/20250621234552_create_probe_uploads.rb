class CreateProbeUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :probe_uploads do |t|
      t.string :name, null: false
      t.integer :status, default: 0, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :probe_uploads, :status
    add_index :probe_uploads, :created_at
  end
end
