module Stats
  class ProbesPassedFailedTimelineData
    def initialize(target_id: nil)
      @target_id = target_id
    end

    def call
      end_date = Time.zone.today
      start_date = end_date - 29.days

      dates = []
      asr_percentages = []
      passed_counts = []

      scope = ProbeResult.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      scope = scope.joins(:report).where(reports: { target_id: @target_id }) if @target_id.present?

      daily_passed = Hash.new(0)
      daily_total = Hash.new(0)

      scope.each do |result|
        day_key = result.created_at.to_date.to_s
        daily_passed[day_key] += result.passed.to_i
        daily_total[day_key] += result.total.to_i
      end

      (start_date..end_date).each do |date|
        day_key = date.to_s
        total = daily_total[day_key]
        passed = daily_passed[day_key]

        # Only include dates with actual data
        if total > 0
          dates << date.strftime("%d %b")
          asr_percentage = (passed.to_f / total * 100).round(1)
          asr_percentages << asr_percentage
          passed_counts << passed
        end
      end

      { dates: dates, asr_percentages: asr_percentages, passed_counts: passed_counts }
    end
  end
end
