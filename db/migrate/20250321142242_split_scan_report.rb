class SplitScanReport < ActiveRecord::Migration[8.0]
  def up
    create_table :scans do |t|
      t.string :uuid, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :scans, :uuid, unique: true

    create_join_table :scans, :targets do |t|
      t.index [ :scan_id, :target_id ], unique: true
    end
    add_foreign_key :scans_targets, :scans
    add_foreign_key :scans_targets, :targets

    create_join_table :probes, :scans do |t|
      t.index [ :scan_id, :probe_id ], unique: true
    end
    add_foreign_key :probes_scans, :scans
    add_foreign_key :probes_scans, :probes

    create_table :reports do |t|
      t.string :uuid, null: false
      t.string :name, null: false
      t.references :target, null: false, foreign_key: true
      t.references :scan, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.json :report_data, default: {}
      t.json :stats, default: {}
      t.timestamps
    end
    add_index :reports, :uuid, unique: true
    add_index :reports, :status
    add_index :reports, [ :scan_id, :target_id ], unique: true

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO scans (uuid, name, created_at, updated_at)
      SELECT uuid, name, created_at, updated_at
      FROM scan_reports
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO scans_targets (scan_id, target_id)
      SELECT scans.id, scan_reports.target_id
      FROM scan_reports
      JOIN scans ON scans.uuid = scan_reports.uuid
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO probes_scans (scan_id, probe_id)
      SELECT scans.id, probes_scan_reports.probe_id
      FROM probes_scan_reports
      JOIN scan_reports ON scan_reports.id = probes_scan_reports.scan_report_id
      JOIN scans ON scans.uuid = scan_reports.uuid
    SQL

    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO reports (uuid, name, target_id, scan_id, status, report_data, stats, created_at, updated_at)
      SELECT scan_reports.uuid, scan_reports.name, scan_reports.target_id, scans.id, scan_reports.status,
            scan_reports.report_data, scan_reports.stats, scan_reports.created_at, scan_reports.updated_at
      FROM scan_reports
      JOIN scans ON scans.uuid = scan_reports.uuid
    SQL

    drop_table :scan_reports if ActiveRecord::Base.connection.table_exists?(:scan_reports)
    drop_table :probes_scan_reports if ActiveRecord::Base.connection.table_exists?(:probes_scan_reports)
  end

  def down
    drop_table :scans_targets
    drop_table :probes_scans
    drop_table :reports
    drop_table :scans
  end
end
