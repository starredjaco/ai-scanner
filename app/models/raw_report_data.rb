# frozen_string_literal: true

# Stores raw garak scan output for cross-pod processing.
#
# This model enables multi-pod deployment by storing report data in PostgreSQL
# instead of relying on filesystem-based Unix sockets.
#
# Lifecycle (Data-First commit pattern):
#   1. JournalSyncThread creates/updates record with status=pending during scan
#   2. notify_report_ready_from_synced enqueues ProcessReportJob
#   3. Job processes the report using jsonl_data and logs_data
#   4. Job deletes the record after successful processing
#
# Note: Data committed before queue job. If queue commit fails, orphan records
# are recovered by OrphanRawReportDataJob.
#
class RawReportData < ApplicationRecord
  belongs_to :report

  # Status enum matching codebase conventions (integer-based)
  enum :status, {
    pending: 0,     # Waiting to be processed
    processing: 1   # Being processed by a Rails worker
  }

  validates :report_id, presence: true, uniqueness: true
  validates :jsonl_data, presence: true
  validates :status, presence: true

  # Mark as processing (called when job starts)
  def mark_processing!
    update!(status: :processing)
  end

  # Parse JSONL data line by line, yielding each parsed JSON object.
  #
  # @yield [Hash] Each parsed JSON line
  # @return [Enumerator] If no block given
  def each_jsonl_line(&block)
    return to_enum(:each_jsonl_line) unless block_given?

    jsonl_data.each_line do |line|
      next if line.strip.empty?
      yield JSON.parse(line)
    rescue JSON::ParserError => e
      Rails.logger.warn("RawReportData##{id}: JSON parse error: #{e.message}")
      next
    end
  end
end
