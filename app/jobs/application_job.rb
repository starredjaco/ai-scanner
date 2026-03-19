class ApplicationJob < ActiveJob::Base
  require "logging"

  around_perform do |job, block|
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Logging.with(job_class: job.class.name, job_id: job.job_id) do
      Rails.logger.info("job.started")
      begin
        block.call
      rescue => e
        # include exception context for failure visibility
        Logging.with(exception_class: e.class.name, exception_message: e.message.to_s) do
          Rails.logger.error("job.failed")
        end
        raise
      ensure
        dur_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
        Logging.with(duration_ms: dur_ms) do
          Rails.logger.info("job.finished")
        end
      end
    end
  end
end
