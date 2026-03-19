module Stats
  class ReportsTimelineData
    def initialize(target_id: nil, scan_id: nil)
      @target_id = target_id
      @scan_id = scan_id
    end

    def call
      end_date = Time.zone.today
      start_date = end_date - 29.days

      dates = []
      counts = []

      scope = Report.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      scope = scope.where(target_id: @target_id) if @target_id.present?
      scope = scope.where(scan_id: @scan_id) if @scan_id.present?
      reports_by_day = scope.group("created_at::date").count

      base_query = Report.where("created_at < ?", start_date.beginning_of_day)
      base_query = base_query.where(target_id: @target_id) if @target_id.present?
      base_query = base_query.where(scan_id: @scan_id) if @scan_id.present?
      cumulative_count = base_query.count

      (start_date..end_date).each do |date|
        daily_count = reports_by_day[date] || 0
        cumulative_count += daily_count

        dates << date.strftime("%d %b")
        counts << cumulative_count
      end

      { dates: dates, counts: counts }
    end
  end
end
