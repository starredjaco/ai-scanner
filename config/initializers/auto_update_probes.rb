Rails.application.config.after_initialize do
  if !Rails.env.test? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    # Queue job to run in 1 minute, which will then reschedule itself every 24h
    DownloadLatestProbePackJob.set(wait: 1.minute).perform_later
    Rails.logger.info "Scheduled automatic probe update check for 1 minute from now (then every 24h)"
  end
end
