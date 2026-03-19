module Stats
  class DetectorActivityData
    def initialize(target_id: nil, scan_id: nil, report_id: nil)
      @target_id = target_id
      @scan_id = scan_id
      @report_id = report_id
    end

    def call
      start_date = Time.zone.today - 30.days
      end_date = Time.zone.today

      top_detectors = DetectorResult.joins(:detector, :report)
                        .where(reports: { created_at: start_date.beginning_of_day..end_date.end_of_day })
      top_detectors = top_detectors.where(reports: { target_id: @target_id }) if @target_id.present?
      top_detectors = top_detectors.where(reports: { scan_id: @scan_id }) if @scan_id.present?
      top_detectors = top_detectors.where(report_id: @report_id) if @report_id.present?
      top_detectors = top_detectors.select("detectors.name, SUM(detector_results.total) as total_tests, SUM(detector_results.passed) as passed_tests")
                        .group("detectors.id, detectors.name")
                        .order("total_tests DESC")
      detector_names = []
      test_counts = []
      passed_counts = []

      top_detectors.each do |result|
        short_name = result.name.split(".").last
        detector_names << I18n.t("detectors.names.#{short_name}", default: short_name)
        test_counts << result.total_tests
        passed_counts << result.passed_tests
      end

      {
        detector_names: detector_names,
        test_counts: test_counts,
        passed_counts: passed_counts,
        time_range: "Last 30 Days"
      }
    end
  end
end
