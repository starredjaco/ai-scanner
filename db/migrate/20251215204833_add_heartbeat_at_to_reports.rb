# frozen_string_literal: true

# Adds heartbeat_at column to reports table for multi-pod scan health monitoring.
#
# Background:
#   The current SyncRunningScans service uses `pgrep -f garak` to verify scan
#   processes are alive. This fails in multi-pod deployments because Pod A
#   cannot see Pod B's processes.
#
# Solution:
#   - Python process updates heartbeat_at every 30 seconds while running
#   - Rails job detects stale reports where heartbeat_at < NOW() - 2 minutes
#
# Why heartbeat_at instead of updated_at?
#   - updated_at changes for ANY column change (logs, status, etc.)
#   - heartbeat_at specifically tracks "process is alive"
#   - Enables reliable queries without false positives
#
class AddHeartbeatAtToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :heartbeat_at, :datetime

    # Partial index: only index running reports for efficient stale queries
    # Status value 1 = running (from enum :status in Report model)
    # This keeps the index tiny since running reports are typically <1% of table
    add_index :reports, :heartbeat_at,
              where: "status = 1",
              name: "index_reports_on_heartbeat_running_only"
  end
end
