class LogCleanupJob < ApplicationJob
  queue_as :low_priority

  # Retry with exponential backoff if cleanup fails
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info "Starting scheduled log cleanup job"

    result = Logs::Cleanup.call

    Rails.logger.info "Log cleanup completed: deleted #{result[:deleted_files]} files, " \
                      "freed #{result[:freed_space] / 1.megabyte}MB"

    result
  rescue ArgumentError => e
    # Configuration errors shouldn't be retried
    Rails.logger.error "Log cleanup configuration error: #{e.message}"
    raise # Re-raise but won't retry for ArgumentError
  rescue Errno::EACCES => e
    Rails.logger.error "Log cleanup failed - permission denied: #{e.message}"
    Rails.logger.error "Check file permissions in storage/logs directory"
    raise # Re-raise to trigger retry
  rescue Errno::ENOSPC => e
    Rails.logger.error "Log cleanup failed - no space left on device: #{e.message}"
    Rails.logger.warn "System is out of disk space, cleanup cannot proceed"
    raise # Re-raise to trigger retry
  rescue StandardError => e
    Rails.logger.error "Log cleanup failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise # Re-raise to trigger retry
  end
end
