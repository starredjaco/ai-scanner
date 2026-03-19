# frozen_string_literal: true

class CleanupOldPdfsJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Clean up PDF records older than 24 hours
    old_pdfs = ReportPdf.stale(24)

    old_pdfs.find_each do |report_pdf|
      begin
        # Delete the file if it exists
        if report_pdf.file_path && File.exist?(report_pdf.file_path)
          File.delete(report_pdf.file_path)
          Rails.logger.info("Deleted old PDF file: #{report_pdf.file_path}")
        end

        # Delete the database record
        report_pdf.destroy
      rescue => e
        Rails.logger.error("Failed to cleanup PDF #{report_pdf.id}: #{e.message}")
      end
    end

    Rails.logger.info("Cleaned up #{old_pdfs.count} old PDF files")
  end
end
