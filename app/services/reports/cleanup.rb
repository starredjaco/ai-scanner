module Reports
  class Cleanup
    # Cleans up resources after report processing.
    #
    # In multi-pod deployments, file cleanup is handled by Python's db_notifier
    # on the same pod where the scan ran. This Ruby cleanup handles only
    # database resources that are accessible from any pod.
    #
    # File cleanup responsibility:
    #   - Python db_notifier: JSONL, logs, config files (same pod as scan)
    #   - Ruby Cleanup: raw_report_data table (database, any pod)
    #
    def initialize(report)
      @report = report
    end

    def call
      delete_raw_report_data
    end

    private

    attr_reader :report

    # Clean up any stale raw_report_data that might exist
    # (handles race condition where job runs before primary commit completes)
    def delete_raw_report_data
      RawReportData.where(report_id: report.id).delete_all
    end
  end
end
