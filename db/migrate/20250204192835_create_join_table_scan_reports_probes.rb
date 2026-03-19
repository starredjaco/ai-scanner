class CreateJoinTableScanReportsProbes < ActiveRecord::Migration[8.0]
  def change
    create_join_table :scan_reports, :probes do |t|
      t.index :scan_report_id
      t.index :probe_id
    end
  end
end
