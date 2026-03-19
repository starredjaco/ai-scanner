# frozen_string_literal: true

# Creates raw_report_data table for cross-pod report processing.
#
# This table stores garak scan output (JSONL + logs) in PostgreSQL,
# enabling any pod to process reports regardless of where the scan ran.
#
# Race Condition Prevention:
#   The model uses SELECT ... FOR UPDATE SKIP LOCKED to ensure only
#   one worker can claim and process a record at a time.
#
# Status values (integer enum):
#   0 = pending    - Waiting to be processed
#   1 = processing - Being processed by a Rails worker
#   (Records are deleted after processing, no "completed" state needed)
#
class CreateRawReportData < ActiveRecord::Migration[8.1]
  def change
    create_table :raw_report_data do |t|
      # Foreign key to reports table - one raw_report_data per report
      t.references :report, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }

      # Raw JSONL file content from garak (multi-line JSON, not valid single JSON)
      t.text :jsonl_data, null: false

      # Log file content (optional, may be nil if no logs produced)
      t.text :logs_data

      # Processing status: 0=pending, 1=processing (deleted after processing)
      t.integer :status, null: false, default: 0

      # When processing completed (for debugging/monitoring)
      t.datetime :processed_at

      t.timestamps
    end

    # Partial index for efficient orphan polling and pending record queries
    # Only indexes pending records (status=0), which is a small subset
    add_index :raw_report_data, :created_at,
              where: "status = 0",
              name: "index_raw_report_data_pending_created_at"

    # Index for race-safe claiming: status + id for FOR UPDATE SKIP LOCKED queries
    add_index :raw_report_data, [ :status, :id ],
              where: "status = 0",
              name: "index_raw_report_data_claimable"
  end
end
