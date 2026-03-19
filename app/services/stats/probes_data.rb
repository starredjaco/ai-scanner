module Stats
  class ProbesData
    def initialize(days: 30)
      @days = days
    end

    def call
      end_date = Time.zone.today
      start_date = end_date - (@days - 1).days
      period_ago = Time.zone.today - @days.days

      # Use tier-filtered probes if company context is available
      base_scope = accessible_probes_scope

      probes_by_day = base_scope.where(release_date: start_date.beginning_of_day..end_date.end_of_day)
                                .group("release_date::date::text")
                                .count

      counts = (start_date..end_date).map do |date|
        probes_by_day[date.to_s] || 0
      end
      total = base_scope.count

      # Calculate percentage of probes added in the period
      probes_in_period = Probe.where(release_date: period_ago.beginning_of_day..end_date.end_of_day).count

      percentage_new_last_30_days = if total.zero?
        0
      else
        ((probes_in_period.to_f / total) * 100).round(1)
      end

      {
        total: total,
        counts: counts,
        percentage_new_last_30_days: percentage_new_last_30_days
      }
    end

    private

    def accessible_probes_scope
      company = ActsAsTenant.current_tenant
      if company
        Scanner.configuration.probe_access_class_constant.new(company).accessible_probes
      else
        Probe.all
      end
    end
  end
end
