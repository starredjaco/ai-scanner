module Stats
  class ProbeDisclosureStats
    def initialize(options = {})
    end

    def call
      # Single GROUP BY query instead of N+1 COUNT queries
      counts_by_status = Probe.group(:disclosure_status).count

      # Build response maintaining enum-defined order
      labels = Probe.disclosure_statuses.keys
      values = labels.map { |label| counts_by_status[label] || 0 }

      {
        labels: labels,
        values: values
      }
    end
  end
end
