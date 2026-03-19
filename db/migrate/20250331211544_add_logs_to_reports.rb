class AddLogsToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :logs, :text
  end
end
