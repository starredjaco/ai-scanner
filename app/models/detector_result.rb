class DetectorResult < ApplicationRecord
  belongs_to :detector
  belongs_to :report

  validates :detector_id, uniqueness: { scope: :report_id }

  def self.ransackable_attributes(auth_object = nil)
    [ "detector_id", "report_id", "passed", "total", "max_score", "created_at", "id", "updated_at" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "detector", "report" ]
  end

  def asr_percentage
    return 0 if total.nil? || total.zero?

    (passed.to_f / total * 100).round
  end
end
