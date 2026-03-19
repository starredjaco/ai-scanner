class AddRecurrenceToScans < ActiveRecord::Migration[8.0]
  def change
    add_column :scans, :recurrence, :jsonb
    add_column :scans, :next_scheduled_run, :datetime
  end
end
