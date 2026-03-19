class CreateScanReports < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_reports do |t|
      t.string :uuid, null: false
      t.references :target, null: false, foreign_key: true
      t.string :name, null: false
      t.json :report_data
      t.integer :status, default: 0

      t.timestamps
    end
    add_index :scan_reports, :uuid, unique: true
  end
end
