# frozen_string_literal: true

class BroadcastRunningStatsJob < ApplicationJob
  queue_as :default

  # Debounce rapid status changes per company.
  # Use company_id in key to allow parallel broadcasts for different companies.
  limits_concurrency to: 1, key: ->(company_id) { "broadcast_running_stats:#{company_id}" }, on_conflict: :discard

  # Broadcasts running report stats for a specific company and global totals.
  #
  # @param company_id [Integer] The company to broadcast stats for (required).
  def perform(company_id)
    broadcast_company_stats(company_id)
    broadcast_global_stats
  end

  private

  def broadcast_company_stats(company_id)
    stats = calculate_company_stats(company_id)
    Rails.cache.write(cache_key_for(company_id), stats, expires_in: 1.hour)

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name_for(company_id),
      target: "system-status-company",
      partial: "application/system_status_company",
      locals: { stats: stats }
    )
  end

  def broadcast_global_stats
    stats = calculate_global_stats
    Rails.cache.write(cache_key_for(:global), stats, expires_in: 1.hour)

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name_for(:global),
      target: "system-status-global",
      partial: "application/system_status_global",
      locals: { stats: stats }
    )
  end

  def calculate_company_stats(company_id)
    scans = Report.where(company_id: company_id).active.where(parent_report_id: nil).count
    variants = Report.where(company_id: company_id).active.where.not(parent_report_id: nil).count
    { scans: scans, variants: variants, total: scans + variants }
  end

  def calculate_global_stats
    ActsAsTenant.without_tenant do
      scans = Report.active.where(parent_report_id: nil).count
      variants = Report.active.where.not(parent_report_id: nil).count
      priority = Report.active.where(parent_report_id: nil).joins(:scan).where(scans: { priority: true }).count
      { scans: scans, variants: variants, priority: priority, total: scans + variants }
    end
  end

  def cache_key_for(identifier)
    "running_scans_stats:#{identifier}"
  end

  def stream_name_for(identifier)
    identifier == :global ? "system-status:global" : "system-status:company_#{identifier}"
  end
end
