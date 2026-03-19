# frozen_string_literal: true

class GeneratePdfJob < ApplicationJob
  queue_as :default

  # Ensure only one PDF generation job per report_id can be enqueued/running at a time
  limits_concurrency to: 1, key: ->(report_id) { "generate_pdf_#{report_id}" }, on_conflict: :discard

  # Retry with exponential backoff for transient failures
  # Wait sequence: 3s, 18s, 83s, 258s, 627s (approximately)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry if report was deleted - it's a permanent failure
  discard_on ActiveRecord::RecordNotFound

  def perform(report_id)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    report = Report.find(report_id)

    # Get the ReportPdf record (created by controller)
    report_pdf = report.report_pdf

    # If already completed and file exists, skip regeneration
    return if report_pdf&.ready?

    # Mark as processing
    report_pdf.update!(status: :processing)

    begin
      # Generate PDF using existing service
      pdf_generator = Reports::PdfGenerator.new(ReportDecorator.new(report))

      # Create storage directory if it doesn't exist
      storage_dir = Rails.root.join("storage", "pdfs")
      FileUtils.mkdir_p(storage_dir)

      # Simple filename without timestamp
      filename = "report_#{report.id}.pdf"
      file_path = storage_dir.join(filename).to_s

      # Generate and save PDF
      pdf_content = pdf_generator.generate
      File.binwrite(file_path, pdf_content)

      # Calculate generation time
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      # Update record with success
      report_pdf.update!(
        status: :completed,
        file_path: file_path,
        error_message: nil
      )

      Rails.logger.info("Successfully generated PDF for report #{report_id} at #{file_path} in #{duration_ms}ms")

      # Collect metrics
      collect_metrics(report, duration_ms, pdf_content.bytesize, success: true)

      # Broadcast completion to company-scoped stream
      broadcast_pdf_ready(report)
    rescue => e
      # Calculate generation time even on failure
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      # Update record with failure
      report_pdf.update!(
        status: :failed,
        error_message: "#{e.class}: #{e.message}"
      )

      Rails.logger.error("PDF generation failed for report #{report_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      # Collect failure metrics
      collect_metrics(report, duration_ms, 0, success: false, error: e.class.name)

      # Re-raise to trigger retry logic
      raise
    end
  end

  private

  def broadcast_pdf_ready(report)
    # Broadcast to company-scoped PDF stream using Turbo
    # Replace the hidden status div with one that has the ready attributes
    Turbo::StreamsChannel.broadcast_replace_to(
      "pdf_notifications:company_#{report.company_id}",
      target: "pdf-status-#{report.id}",
      html: "<div id='pdf-status-#{report.id}' style='display: none;' data-pdf-status='ready' data-download-url='#{Rails.application.routes.url_helpers.pdf_report_detail_path(report)}'></div>"
    )
  end

  def collect_metrics(report, duration_ms, pdf_size_bytes, success:, error: nil)
    return unless MonitoringService.active?

    labels = {
      report_id: report.id,
      report_uuid: report.uuid,
      target_name: report.target.name,
      scan_name: report.scan.name,
      pdf_generation_duration_ms: duration_ms,
      pdf_generation_success: success ? 1 : 0,
      pdf_size_bytes: pdf_size_bytes
    }

    labels[:pdf_generation_error] = error if error

    MonitoringService.set_labels(labels)

    Rails.logger.info("[Metrics] PDF generation: report=#{report.id} duration=#{duration_ms}ms size=#{pdf_size_bytes}bytes success=#{success}")
  end
end
