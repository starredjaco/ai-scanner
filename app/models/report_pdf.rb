class ReportPdf < ApplicationRecord
  belongs_to :report

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }, prefix: true

  validates :report, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :stale, ->(hours = 24) { where("created_at < ?", hours.hours.ago) }

  # Check if PDF is ready to serve
  def ready?
    status_completed? && file_path.present? && File.exist?(file_path)
  end

  # Get the file size in bytes
  def file_size
    return nil unless file_path && File.exist?(file_path)
    File.size(file_path)
  end
end
