# frozen_string_literal: true

class AddCachedStatsToProbes < ActiveRecord::Migration[8.0]
  def up
    # Add counter columns for caching aggregated probe_results stats
    add_column :probes, :cached_passed_count, :bigint, default: 0, null: false
    add_column :probes, :cached_total_count, :bigint, default: 0, null: false

    # Backfill from existing data using efficient single UPDATE with subquery
    execute <<~SQL
      UPDATE probes SET
        cached_passed_count = COALESCE(stats.sum_passed, 0),
        cached_total_count = COALESCE(stats.sum_total, 0)
      FROM (
        SELECT
          probe_id,
          SUM(passed) as sum_passed,
          SUM(total) as sum_total
        FROM probe_results
        GROUP BY probe_id
      ) stats
      WHERE probes.id = stats.probe_id
    SQL

    # Index for sorting by success rate
    add_index :probes, :cached_total_count,
              name: "index_probes_on_cached_total_count"

    # Composite index for efficient success rate queries
    add_index :probes, [ :cached_passed_count, :cached_total_count ],
              name: "index_probes_on_cached_stats"
  end

  def down
    remove_index :probes, name: "index_probes_on_cached_stats"
    remove_index :probes, name: "index_probes_on_cached_total_count"
    remove_column :probes, :cached_passed_count
    remove_column :probes, :cached_total_count
  end
end
