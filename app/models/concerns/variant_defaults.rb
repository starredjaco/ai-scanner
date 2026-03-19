module VariantDefaults
  extend ActiveSupport::Concern

  # Safe defaults for variant functionality and notification methods.
  # The engine overrides these when loaded via engine concern (include).
  # Because both are modules, the last included module wins in the ancestor chain.
  #
  # NOTE: notify_* methods live here (not in the class body) so the engine can
  # override them via include. Ruby MRO gives class-body methods priority over
  # included modules, but module-vs-module respects inclusion order (last wins).

  def is_variant_report?
    false
  end

  def has_variant_data?
    false
  end

  def should_show_variants_section?
    false
  end

  def variant_report_ready?
    false
  end

  def variant_count
    0
  end

  def all_attempts_for_probe(probe_result)
    return [] unless probe_result
    (probe_result.attempts || []).map do |attempt|
      { attempt: attempt, is_variant: false, variant_industry: nil }
    end
  end

  def preloaded_variant_data
    { attack_counts: {}, success_rates: {}, subindustry_maps: {}, all_attempts: {} }
  end

  private

  def notify_status_change
    case status.to_sym
    when :completed
      notify_scan_completed
    when :failed
      notify_scan_failed
    end
  end

  def notify_scan_completed
    ToastNotifier.call(
      type: "success",
      title: "Scan Completed",
      message: "Scan #{name} has completed successfully.",
      link: Rails.application.routes.url_helpers.report_path(self),
      link_text: "View Report",
      company_id: company_id
    )
  end

  def notify_scan_failed
    ToastNotifier.call(
      type: "error",
      title: "Scan Failed",
      message: "Scan #{name} has failed.",
      link: Rails.application.routes.url_helpers.report_path(self),
      link_text: "View Report",
      company_id: company_id
    )
  end
end
