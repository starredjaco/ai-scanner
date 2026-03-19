class AddReportsCountToScans < ActiveRecord::Migration[8.1]
  def up
    add_column :scans, :reports_count, :integer, default: 0, null: false

    # Add index for efficient ORDER BY reports_count queries
    add_index :scans, :reports_count

    # Backfill existing data using efficient SQL UPDATE
    # Counts ALL reports (parent + child) per scan
    execute <<~SQL
      UPDATE scans
      SET reports_count = (
        SELECT COUNT(*)
        FROM reports
        WHERE reports.scan_id = scans.id
      )
    SQL
  end

  def down
    remove_index :scans, :reports_count
    remove_column :scans, :reports_count
  end
end
