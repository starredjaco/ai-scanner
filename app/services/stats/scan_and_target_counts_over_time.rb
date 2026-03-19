module Stats
  class ScanAndTargetCountsOverTime < ApplicationService
    def initialize(days: 7)
      @days = days
    end

    def call
      scan_data = Stats::TotalScansData.call(days: @days)
      target_data = Stats::TargetsTimelineData.call(days: @days)

      scan_by_date = build_date_hash(scan_data)
      target_by_date = build_date_hash(target_data)

      all_dates = (scan_by_date.keys + target_by_date.keys).uniq.sort
      all_dates.map do |date|
        {
          date: date,
          scan_count: scan_by_date[date] || 0,
          target_count: target_by_date[date] || 0
        }
      end
    end

    private

    def build_date_hash(data)
      return {} unless data[:dates] && data[:counts]
      data[:dates].zip(data[:counts]).to_h
    end
  end
end
