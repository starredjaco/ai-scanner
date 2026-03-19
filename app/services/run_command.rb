class RunCommand
  # Brief sleep to detect immediate process failures after launch.
  # 0.5 seconds balances two goals:
  # - Long enough to catch most immediate startup failures
  # - Short enough to avoid noticeable delays in normal operation
  PROCESS_START_DETECTION_DELAY = 0.5

  attr_reader :command

  def initialize(command)
    @command = command
  end

  def call
    stdout, stderr, status = Open3.capture3(command)

    raise "Command failed with error: #{stderr}" unless status.success?

    stdout
  end

  def call_async
    # Run through bash shell to handle env vars, pipes, and redirections
    # Command string already includes env vars as prefix (e.g., "VAR=value command")
    Rails.logger.info("RunCommand.call_async executing: #{sanitize_command_for_logging(command)}")

    stdin, stdout, stderr, wait_thr = Open3.popen3("/bin/bash", "-c", command)
    stdin.close

    # Spawn a thread to monitor stdout and log to Rails logger
    # This makes process output visible in docker compose logs
    Thread.new do
      begin
        stdout.each_line do |line|
          Rails.logger.info("Process: #{line.chomp}")
        end
      rescue => e
        Rails.logger.error("Error reading stdout: #{e.message}")
      ensure
        stdout.close
      end
    end

    # Spawn a thread to monitor stderr and log any errors
    Thread.new do
      begin
        stderr.each_line do |line|
          Rails.logger.error("Process stderr: #{line.chomp}")
        end
      rescue => e
        Rails.logger.error("Error reading stderr: #{e.message}")
      ensure
        stderr.close
      end
    end

    # Brief sleep to detect immediate failures
    sleep PROCESS_START_DETECTION_DELAY
    if wait_thr.status == false || wait_thr.status.nil?
      Rails.logger.error("Process exited immediately with status: #{wait_thr.value.exitstatus}")
      Rails.logger.error("Command was: #{command}")
    else
      Rails.logger.info("Process started successfully with PID: #{wait_thr.pid}")
    end

    wait_thr
  end

  private

  def sanitize_command_for_logging(cmd)
    # Mask sensitive environment variables (API keys, tokens, secrets)
    sanitized = cmd.dup

    # List of env var patterns to sanitize
    sensitive_patterns = [
      /([A-Z_]*API[_A-Z]*KEY=)[^\s]+/i,
      /([A-Z_]*TOKEN[_A-Z]*=)[^\s]+/i,
      /([A-Z_]*SECRET[_A-Z]*=)[^\s]+/i,
      /([A-Z_]*PASSWORD[_A-Z]*=)[^\s]+/i,
      /(OPENAI_API_KEY=)[^\s]+/,
      /(HF_INFERENCE_TOKEN=)[^\s]+/,
      /(OPENROUTER_API_KEY=)[^\s]+/
    ]

    sensitive_patterns.each do |pattern|
      sanitized.gsub!(pattern, '\1***REDACTED***')
    end

    # Truncate to avoid logging extremely long commands
    sanitized.length > 300 ? "#{sanitized[0..297]}..." : sanitized
  end
end
