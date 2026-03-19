class AddIndexesToProbeResults < ActiveRecord::Migration[8.0]
  def change
    # Index on created_at for time-based queries (last 90 days)
    add_index :probe_results, :created_at

    # Index on passed for filtering vulnerable results (passed > 0)
    add_index :probe_results, :passed

    # Composite index for the common query pattern: probe_id + created_at + passed
    # This will be especially useful for the successful_targets_last_90_days method
    add_index :probe_results, [ :probe_id, :created_at, :passed ]
  end
end
