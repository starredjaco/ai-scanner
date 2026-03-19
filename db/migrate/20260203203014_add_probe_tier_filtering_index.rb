# frozen_string_literal: true

# Adds composite index for tier-based probe filtering
#
# The ProbeAccess service filters probes using:
#   WHERE enabled = true
#     AND disclosure_status = 'n-day'
#     AND release_date <= 1.month.ago
#     AND (hash calculation)
#
# This index optimizes the first three conditions, significantly
# improving query performance as the probe count grows.
class AddProbeTierFilteringIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :probes,
              [ :enabled, :disclosure_status, :release_date ],
              name: "index_probes_on_tier_filtering",
              algorithm: :concurrently
  end
end
