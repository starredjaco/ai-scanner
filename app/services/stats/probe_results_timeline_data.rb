module Stats
  class ProbeResultsTimelineData
    def initialize(probe_id:)
      @probe_id = probe_id
    end

    def call
      end_date = Time.zone.today
      start_date = end_date - 29.days

      probe = Probe.find_by!(id: @probe_id)
      scope = probe.probe_results.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

      daily_passed = Hash.new(0)
      daily_failed = Hash.new(0)
      daily_total = Hash.new(0)
      scope.find_each do |result|
        day_key = result.created_at.to_date.to_s
        daily_passed[day_key] += result.passed
        daily_total[day_key] += result.total
        daily_failed[day_key] += result.total - result.passed
      end

      dates = []
      passed_counts = []
      failed_counts = []
      total_counts = []

      (start_date..end_date).each do |date|
        day_key = date.to_s
        dates << date.strftime("%d %b")
        passed_counts << daily_passed[day_key]
        failed_counts << daily_failed[day_key]
        total_counts << daily_total[day_key]
      end

      { dates: dates, passed_counts: passed_counts, failed_counts: failed_counts, total_counts: total_counts }
    end
  end
end
