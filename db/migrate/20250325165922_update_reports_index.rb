class UpdateReportsIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :reports, name: "index_reports_on_scan_id_and_target_id"
  end
end
