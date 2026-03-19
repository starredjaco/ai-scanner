# frozen_string_literal: true

# Scheduled job that cleans up old reports based on the configured retention strategy.
#
# Runs daily at 4:00am (configured in config/recurring.yml).
# Delegates to Retention::Cleanup which uses Scanner.configuration.retention_strategy_class.
#
# OSS default: Retention::SimpleStrategy (fixed 90-day retention, configurable via RETENTION_DAYS env)
# Engine override: engine tier retention (tier-based with grace periods)
#
class RetentionCleanupJob < ApplicationJob
  queue_as :low_priority

  # Only one instance should run at a time to prevent duplicate processing
  limits_concurrency to: 1, key: -> { "retention_cleanup" }, on_conflict: :discard

  # Retry with exponential backoff if cleanup fails
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info "[RetentionCleanup] Starting scheduled retention cleanup"

    result = Retention::Cleanup.call

    Rails.logger.info "[RetentionCleanup] Completed: " \
      "#{result[:companies_processed]} companies processed, " \
      "#{result[:reports_deleted]} reports deleted"

    if result[:errors].any?
      result[:errors].each do |error|
        Rails.logger.warn "[RetentionCleanup] Error for company #{error[:company_id]}: #{error[:message]}"
      end
    end

    result
  end
end
