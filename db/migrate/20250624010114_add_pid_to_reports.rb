class AddPidToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :pid, :integer
  end
end
