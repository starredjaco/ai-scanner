# frozen_string_literal: true

class ProcessReportJob < ApplicationJob
  queue_as :default

  # Ensure only one job per report_id can be enqueued/running at a time.
  # Duplicate jobs (e.g., from orphan poller) are silently discarded.
  limits_concurrency to: 1, key: ->(report_id) { "process_report_#{report_id}" }, on_conflict: :discard

  # Retry with exponential backoff for transient failures (e.g., raw_report_data not yet committed)
  # Wait sequence: 3s, 18s, 83s, 258s, 627s (approximately)
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # Don't retry if report was deleted - it's a permanent failure
  discard_on ActiveRecord::RecordNotFound

  before_perform do |job|
    if MonitoringService.active? && job.executions > 0
      report = Report.find(job.arguments.first)

      labels = {
        report_uuid: report.uuid,
        scan_name: report.scan.name,
        target_name: report.target.name,
        retry_attempt: job.executions
      }

      MonitoringService.report_event(
        "ProcessReportJob retry",
        custom: labels.merge(
          job_class: self.class.name,
          report_id: job.arguments.first
        )
      )
    end
  rescue ActiveRecord::RecordNotFound
  end

  def perform(report_id)
    report = Report.find(report_id)
    ActsAsTenant.with_tenant(report.company) do
      Reports::Process.new(report_id).call
      Scanner.run_hooks(:after_report_process, { report: report.reload, company: report.company })
    end
  end
end
