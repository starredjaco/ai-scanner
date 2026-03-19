module Stats
  class LastFiveScansData
    def call
      # Get the last 5 completed reports with pre-aggregated probe_results stats
      # Using a single SQL query with GROUP BY to avoid N+1 queries
      last_five_reports = Report
        .joins(:target)
        .left_joins(:probe_results)
        .where(status: Report.statuses[:completed])
        .group("reports.id", "targets.name")
        .select(
          "reports.id",
          "reports.created_at",
          "targets.name as target_name",
          "COALESCE(SUM(probe_results.passed), 0) as total_passed",
          "COALESCE(SUM(probe_results.total), 0) as total_tests"
        )
        .order(created_at: :desc)
        .limit(5)

      models = []
      scores = []
      report_ids = []

      last_five_reports.each do |report|
        total_passed = report.total_passed.to_i
        total_tests = report.total_tests.to_i
        score = total_tests.zero? ? 0 : ((total_passed.to_f / total_tests) * 100).round(0)

        models << report.target_name
        scores << score
        report_ids << report.id
      end

      {
        models: models,
        values: scores,
        report_ids: report_ids
      }
    end
  end
end
