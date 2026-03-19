module Stats
  class TargetsTimelineData < ApplicationService
    def initialize(days: 30)
      @days = days
    end

    def call
      end_date = Time.zone.today
      start_date = end_date - (@days - 1).days

      dates = []
      counts = []

      targets_by_day = Target.where(created_at: start_date.beginning_of_day..end_date.end_of_day).group("created_at::date").count
      cumulative_count = Target.where("created_at < ?", start_date.beginning_of_day).count

      (start_date..end_date).each do |date|
        daily_count = targets_by_day[date] || 0
        cumulative_count += daily_count

        dates << date.strftime("%d %b")
        counts << cumulative_count
      end

      { dates: dates, counts: counts }
    end
  end
end
