module Stats
  class AvgScanTimeData
    def initialize(days: 7)
      @days = days.to_i
      @days = 7 if @days <= 0
    end

    def call
      query_scope = Report.where.not(start_time: nil).where.not(end_time: nil)
                        .where("start_time < end_time")
                        .where("created_at >= ?", @days.days.ago)

      avg_time_in_seconds = query_scope
                              .reorder(nil)
                              .pluck(Arel.sql("AVG(EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER)"))
                              .first.to_i

      trend_data = get_trend_data(@days)

      previous_period_end = @days.days.ago
      previous_period_start = previous_period_end - @days.days

      previous_avg = Report.where.not(start_time: nil).where.not(end_time: nil)
                          .where("start_time < end_time")
                          .where("created_at >= ?", previous_period_start)
                          .where("created_at < ?", previous_period_end)
                          .reorder(nil)
                          .pluck(Arel.sql("AVG(EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER)"))
                          .first.to_i

      has_current_data = avg_time_in_seconds > 0
      has_previous_data = previous_avg > 0

      percentage_change = if !has_current_data && !has_previous_data
                            nil
      elsif !has_previous_data
                            100
      elsif !has_current_data
                            -100
      else
                            ((avg_time_in_seconds - previous_avg) / previous_avg.to_f * 100).round(1)
      end

      formatted_time = format_duration(avg_time_in_seconds)

      {
        avg_seconds: avg_time_in_seconds,
        formatted_time: formatted_time,
        percentage_change: percentage_change,
        trend_data: trend_data,
        period_days: @days
      }
    end

    private

    def format_duration(seconds)
      return "0s" if seconds <= 0

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      remaining_seconds = seconds % 60

      if hours > 0
        if minutes > 0
          "#{hours}h #{minutes}m"
        else
          "#{hours}h"
        end
      elsif minutes > 0
        if remaining_seconds > 0
          "#{minutes}m #{remaining_seconds}s"
        else
          "#{minutes}m"
        end
      else
        "#{remaining_seconds}s"
      end
    end

    def get_trend_data(days)
      if days <= 7
        trend_data = 7.times.map do |i|
          day_start = (7 - i - 1).days.ago.beginning_of_day
          day_end = (7 - i - 1).days.ago.end_of_day

          get_average_for_period(day_start, day_end)
        end
      elsif days <= 30
        trend_data = 5.times.map do |i|
          week_start = [ 30, (5 - i) * 7 ].min.days.ago
          week_end = [ (5 - i - 1) * 7, 0 ].max.days.ago

          get_average_for_period(week_start, week_end)
        end
      elsif days <= 60
        trend_data = 6.times.map do |i|
          period_start = [ 60, (6 - i) * 10 ].min.days.ago
          period_end = [ (6 - i - 1) * 10, 0 ].max.days.ago

          get_average_for_period(period_start, period_end)
        end
      else
        trend_data = 12.times.map do |i|
          month_start = (12 - i).months.ago.beginning_of_month
          month_end = (11 - i).months.ago.end_of_month

          get_average_for_period(month_start, month_end)
        end
      end

      trend_data.presence || [ 0, 0, 0, 0, 0 ]
    end

    def get_average_for_period(start_date, end_date)
      avg = Report.where.not(start_time: nil).where.not(end_time: nil)
                  .where("start_time < end_time")
                  .where("created_at >= ?", start_date)
                  .where("created_at <= ?", end_date)
                  .reorder(nil)
                  .pluck(Arel.sql("AVG(EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER)"))
                  .first.to_i

      avg || 0
    end
  end
end
