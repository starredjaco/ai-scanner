Rails.application.config.after_initialize do
  next if Rails.env.test?
  next if ENV["SECRET_KEY_BASE_DUMMY"].present?
  next unless defined?(Rails::Server) || defined?(SolidQueue::CLI)

  # Schedule probe sync on boot; the job checks each source via ProbeSourceRegistry
  Rails.logger.info "Scheduling probe sync check on boot..."
  SyncProbesJob.perform_later
end
