module Stats
  class AttackFailsByTargetData
    def initialize(scan_id: nil)
      @scan_id = scan_id
    end

    def call
      end_date = Time.zone.today
      start_date = end_date - 29.days
      dates = []

      (start_date..end_date).each do |date|
        dates << date.strftime("%d %b")
      end

      date_range = start_date.beginning_of_day..end_date.end_of_day

      # Get main results - aggregate detector results by target and date
      results = DetectorResult.joins(report: [ :target, :scan ])
                  .where(reports: { created_at: date_range })
                  .select(
                    "targets.id as target_id",
                    "targets.name as target_name",
                    "targets.model_type",
                    "targets.model",
                    "reports.created_at::date as report_date",
                    "SUM(detector_results.total) as total_tests",
                    "SUM(detector_results.passed) as passed_tests"
                  )
                  .group("targets.id", "targets.name", "targets.model_type", "targets.model", "report_date")

      results = results.where(reports: { scan_id: @scan_id }) if @scan_id.present?

      targets_data = {}
      scan_summary = {
        total_reports: 0,
        total_tests: 0,
        total_passed: 0,
        total_failed: 0,
        detector_stats: {}
      }

      # Get detector statistics
      detector_stats = DetectorResult.joins(:detector, report: [ :target, :scan ])
                        .where(reports: { created_at: date_range })
                        .select(
                          "detectors.id",
                          "detectors.name",
                          "targets.id as target_id",
                          "targets.name as target_name",
                          "SUM(detector_results.total) as total_tests",
                          "SUM(detector_results.passed) as passed_tests"
                        )
                        .group("detectors.id", "detectors.name", "targets.id", "targets.name")

      detector_stats = detector_stats.where(reports: { scan_id: @scan_id }) if @scan_id.present?

      # Process detector stats by target
      target_detector_stats = {}
      detector_stats.each do |stat|
        target_detector_stats[stat.target_id] ||= {}
        passed = stat.passed_tests.to_i
        total = stat.total_tests.to_i
        failed = total - passed

        target_detector_stats[stat.target_id][stat.name] = {
          passed: passed,
          failed: failed,
          total: total
        }

        scan_summary[:detector_stats][stat.name] ||= { passed: 0, failed: 0, total: 0 }
        scan_summary[:detector_stats][stat.name][:passed] += passed
        scan_summary[:detector_stats][stat.name][:failed] += failed
        scan_summary[:detector_stats][stat.name][:total] += total
        scan_summary[:total_tests] += total
        scan_summary[:total_passed] += passed
        scan_summary[:total_failed] += failed
      end

      # Get report counts
      report_counts = Report.where(created_at: date_range)
      report_counts = report_counts.where(scan_id: @scan_id) if @scan_id.present?
      target_report_counts = report_counts.group(:target_id).count
      scan_summary[:total_reports] = report_counts.count

      # Process results
      results.each do |result|
        target_id = result.target_id
        targets_data[target_id] ||= {
          id: target_id,
          name: result.target_name,
          model_info: "#{result.model_type} - #{result.model}",
          daily_data: {},
          summary: {
            total_reports: target_report_counts[target_id] || 0,
            total_tests: 0,
            total_passed: 0,
            total_failed: 0,
            model_type: result.model_type,
            model: result.model,
            detector_stats: target_detector_stats[target_id] || {}
          }
        }

        day_key = result.report_date.to_s
        passed = result.passed_tests.to_i
        total = result.total_tests.to_i
        failed = total - passed

        targets_data[target_id][:daily_data][day_key] = {
          passed: passed,
          failed: failed,
          total: total
        }
        targets_data[target_id][:summary][:total_tests] += total
        targets_data[target_id][:summary][:total_passed] += passed
        targets_data[target_id][:summary][:total_failed] += failed
      end

      # Format targets for output
      formatted_targets = targets_data.values.map do |target|
        failed_data = []
        passed_data = []
        total_data = []

        (start_date..end_date).each do |date|
          day_key = date.to_s
          daily_stats = target[:daily_data][day_key] || { passed: 0, failed: 0, total: 0 }

          failed_data << daily_stats[:failed]
          passed_data << daily_stats[:passed]
          total_data << daily_stats[:total]
        end

        success_rate = target[:summary][:total_tests] > 0 ?
                      (target[:summary][:total_passed].to_f / target[:summary][:total_tests] * 100).round(1) :
                      0

        target[:summary][:detector_stats] = target[:summary][:detector_stats].sort_by { |_, stats| -stats[:total] }.to_h

        {
          name: target[:name],
          model_info: target[:model_info],
          failed_data: failed_data,
          passed_data: passed_data,
          total_data: total_data,
          summary: target[:summary].merge({
            success_rate: success_rate
          })
        }
      end

      # Calculate scan success rate
      scan_success_rate = scan_summary[:total_tests] > 0 ?
                       (scan_summary[:total_passed].to_f / scan_summary[:total_tests] * 100).round(1) :
                       0

      scan_summary[:success_rate] = scan_success_rate
      scan_summary[:detector_stats] = scan_summary[:detector_stats].sort_by { |_, stats| -stats[:total] }.to_h

      # Return complete result
      {
        dates: dates,
        targets: formatted_targets,
        scan_summary: scan_summary,
        time_range: "Last 30 Days"
      }
    end
  end
end
