class AddStatsToScanReports < ActiveRecord::Migration[8.0]
  def change
    add_column :scan_reports, :stats, :jsonb, default: {}
  end
end
