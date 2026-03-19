# frozen_string_literal: true

# Detects and recovers orphaned raw_report_data records.
#
# An orphan occurs when Python successfully commits data to the primary database
# but fails to commit the job to the queue database (network issue, crash, etc.).
# This is a designed failure mode of the Data-First commit pattern.
#
# This job runs periodically to create missing ProcessReportJob entries,
# ensuring all report data is eventually processed.
#
# @see notify_report_ready in script/db_notifier.py (commits primary first, queue second)
# @see ProcessReportJob (has limits_concurrency to prevent duplicate processing)
#
class OrphanRawReportDataJob < ApplicationJob
  queue_as :default

  # Only one instance should run at a time to prevent duplicate detection
  limits_concurrency to: 1, key: -> { "orphan_raw_report_data" }, on_conflict: :discard

  # Grace period before considering a record orphaned.
  # Normal flow completes in seconds; this catches only true orphans.
  # Must be longer than typical database commit + job enqueue time.
  ORPHAN_THRESHOLD = 5.minutes

  def perform
    orphan_count = recover_orphaned_records
    if orphan_count > 0
      Rails.logger.info("[OrphanPoller] Recovered #{orphan_count} orphaned record(s)")
    else
      Rails.logger.debug("[OrphanPoller] No orphaned records found")
    end
  end

  private

  # Find and recover raw_report_data records that:
  # 1. Are in pending status (not being processed)
  # 2. Are older than ORPHAN_THRESHOLD (not just slow commits)
  # 3. Don't have a pending ProcessReportJob in Solid Queue
  #
  # @return [Integer] Number of orphans recovered
  def recover_orphaned_records
    candidates = find_orphan_candidates
    return 0 if candidates.empty?

    # Get report_ids that already have pending jobs
    report_ids_with_jobs = find_report_ids_with_pending_jobs(candidates.map(&:report_id))

    # Recover orphans (those without pending jobs)
    recovered = 0
    candidates.each do |raw_data|
      next if report_ids_with_jobs.include?(raw_data.report_id)

      if recover_orphan(raw_data)
        recovered += 1
      end
    end

    recovered
  end

  # Find raw_report_data records that might be orphaned.
  # Excludes records for reports that are still active, pending retry,
  # interrupted, or stopped, since JournalSyncThread creates raw_report_data
  # records incrementally during scan execution, pending reports may be about
  # to resume, interrupted reports will be retried by
  # RetryInterruptedReportsJob, and stopped reports are user-cancelled
  # (terminal state that must not be overwritten).
  def find_orphan_candidates
    RawReportData.pending
                 .where("raw_report_data.created_at < ?", ORPHAN_THRESHOLD.ago)
                 .joins(:report)
                 .where.not(reports: { status: [ :running, :starting, :pending, :interrupted, :stopped ] })
                 .limit(100) # Process in batches to avoid memory issues
  end

  # Check which report_ids already have pending ProcessReportJob entries
  #
  # @param report_ids [Array<Integer>] Report IDs to check
  # @return [Set<Integer>] Report IDs that have pending jobs
  def find_report_ids_with_pending_jobs(report_ids)
    return Set.new if report_ids.empty?

    # Query Solid Queue for pending ProcessReportJob entries
    # Jobs are pending if they're in solid_queue_jobs but not finished
    pending_jobs = SolidQueue::Job
      .where(class_name: "ProcessReportJob")
      .where(finished_at: nil)
      .pluck(:arguments)

    # Extract report_ids from job arguments
    pending_report_ids = pending_jobs.filter_map do |arguments_json|
      extract_report_id_from_arguments(arguments_json)
    end

    Set.new(pending_report_ids)
  end

  # Extract report_id from Solid Queue job arguments JSON
  #
  # Job arguments format: {"job_class": "...", "arguments": [report_id], ...}
  def extract_report_id_from_arguments(arguments_json)
    return nil unless arguments_json.present?

    args = arguments_json.is_a?(String) ? JSON.parse(arguments_json) : arguments_json
    args.dig("arguments", 0)&.to_i
  rescue JSON::ParserError => e
    Rails.logger.warn("[OrphanPoller] Failed to parse job arguments: #{e.message}")
    nil
  end

  # Create missing ProcessReportJob for an orphaned record
  #
  # @param raw_data [RawReportData] The orphaned record
  # @return [Boolean] True if job was created successfully
  def recover_orphan(raw_data)
    report_id = raw_data.report_id
    orphan_age = (Time.current - raw_data.created_at).round

    Rails.logger.info(
      "[OrphanPoller] Recovering orphan: report_id=#{report_id}, " \
      "age=#{orphan_age}s, raw_report_data_id=#{raw_data.id}"
    )

    # Enqueue the missing job
    # ProcessReportJob has limits_concurrency with on_conflict: :discard,
    # so duplicate jobs are safely ignored
    ProcessReportJob.perform_later(report_id)

    Rails.logger.info("[OrphanPoller] Created ProcessReportJob for report_id=#{report_id}")
    true
  rescue => e
    Rails.logger.error(
      "[OrphanPoller] Failed to recover report_id=#{report_id}: #{e.class} - #{e.message}"
    )
    false
  end
end
