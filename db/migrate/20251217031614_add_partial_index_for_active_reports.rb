# frozen_string_literal: true

# Adds a partial composite index for the Report.active scope.
#
# The `active` scope filters for running (1) and starting (6) status values.
# This partial index is significantly smaller than a full index since active
# reports are typically < 5 at any time, while completed reports accumulate.
#
# Query patterns optimized:
# - Report.active.count (StartPendingScansJob, every minute)
# - Report.active.where(parent_report_id: nil).count (BroadcastRunningStatsJob)
# - Report.active.where.not(parent_report_id: nil).count (BroadcastRunningStatsJob)
#
# @see app/models/report.rb scope :active
# @see app/jobs/start_pending_scans_job.rb
# @see app/jobs/broadcast_running_stats_job.rb
#
class AddPartialIndexForActiveReports < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Composite partial index: covers status filtering AND parent_report_id filtering
    # Uses raw integer values for status (running: 1, starting: 6)
    add_index :reports,
              [ :status, :parent_report_id ],
              where: "status IN (1, 6)",
              name: "index_reports_on_active_with_parent",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
