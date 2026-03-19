module Stats
  class TotalScansData < ApplicationService
    def initialize(days: 7)
      @days = days
    end

    def call
      # Set up date ranges for current period and charts
      end_date = Time.zone.today
      start_date = end_date - (@days.to_i - 1).days

      period_end = Time.zone.today
      period_start = period_end - @days.to_i.days

      # Define previous period for comparison
      previous_period_end = period_start - 1.day
      previous_period_start = previous_period_end - @days.to_i.days

      # Get report counts for both periods
      current_period_count = Report.where(created_at: period_start.beginning_of_day..period_end.end_of_day).count
      previous_period_count = Report.where(created_at: previous_period_start.beginning_of_day..previous_period_end.end_of_day).count

      # Get data for sparkline chart
      reports_by_day = Report.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                            .group("created_at::date")
                            .count

      counts = (start_date..end_date).map do |date|
        reports_by_day[date] || 0
      end

      total = Report.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count

      # Calculate percentage change between periods
      percentage_change = if previous_period_count.zero?
        current_period_count.positive? ? 100 : 0
      else
        ((current_period_count - previous_period_count).to_f / previous_period_count * 100).round(1)
      end

      {
        total: total,
        counts: counts,
        dates: (start_date..end_date).map { |date| date.strftime("%d %b") },
        percentage_change: percentage_change,
        days: @days
      }
    end
  end
end
