class ReportDetailsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show ], if: :valid_pdf_token?
  skip_before_action :set_tenant, only: [ :show ], if: :valid_pdf_token?
  before_action :set_report
  before_action :set_tenant_from_report, only: [ :show ], if: :valid_pdf_token?

  def show
  end

  def pdf
    report_pdf = @report.report_pdf

    # If PDF is ready, serve it
    if report_pdf&.ready?
      # file_path is set by GeneratePdfJob, not user input
      # the file_path is something like storage/pdfs/report_{report.id}.pdf
      # the filename is based on the target, target name_yyyy-mm-dd.pdf, which is
      # legacy behavior
      return send_file report_pdf.file_path,
                       filename: pdf_filename,
                       type: "application/pdf",
                       disposition: "attachment"
    end

    # If PDF is being generated, return current status
    if report_pdf&.status_processing? || report_pdf&.status_pending?
      return render json: {
        status: report_pdf.status,
        message: "PDF is being generated. Please wait..."
      }, status: :accepted
    end

    # Create ReportPdf record here to prevent race condition
    # Use find_or_create_by with uniqueness constraint to ensure only one exists
    report_pdf = @report.build_report_pdf(status: :pending) unless report_pdf
    report_pdf.save!

    # Start PDF generation job
    GeneratePdfJob.perform_later(@report.id)
    render json: {
      status: "pending",
      message: "PDF generation started. Please wait..."
    }, status: :accepted
  end

  def pdf_status
    report_pdf = @report.report_pdf

    return render json: { status: "not_found" } if report_pdf.nil?

    if report_pdf.ready?
      render json: { status: "completed", download_url: pdf_report_detail_path(@report) }
    elsif report_pdf.status_failed?
      render json: { status: "failed", error: report_pdf.error_message }
    else
      render json: { status: report_pdf.status }
    end
  end

  private

  def set_report
    @report = ReportDecorator.new(Report.find(params[:id]))
  end

  def pdf_filename
    "#{@report.target_name}_#{@report.created_at.strftime('%Y-%m-%d')}.pdf"
  end

  # Verify a short-lived signed token from the internal PDF renderer.
  # This allows the headless browser to access the report without a Devise session.
  def valid_pdf_token?
    return false unless params[:pdf_token].present? && params[:pdf].present?

    report_id = Rails.application.message_verifier("pdf").verify(
      params[:pdf_token],
      purpose: :pdf_render
    )
    report_id.to_s == params[:id].to_s
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    false
  end

  def set_tenant_from_report
    report = Report.find(params[:id])
    ActsAsTenant.current_tenant = report.company
  end
end
