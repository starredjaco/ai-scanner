class AddRetryTrackingToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :retry_count, :integer, default: 0, null: false
    add_column :reports, :last_retry_at, :datetime
  end
end
