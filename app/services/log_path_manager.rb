require "digest"

class LogPathManager
  # Set to true to hash target names for privacy
  USE_HASHED_NAMES = ENV.fetch("LOG_USE_HASHED_NAMES", "false") == "true"

  class << self
    def scan_log_path_for_date(date = Date.current)
      date_dir = date.strftime("%Y/%m/%d")
      path = Rails.root.join("storage/logs/scans", date_dir)
      FileUtils.mkdir_p(path)
      path
    end

    def scan_log_file_for_report(report)
      log_path = scan_log_path_for_date
      target_name = if USE_HASHED_NAMES && report.target&.name
                      # Use first 8 chars of SHA256 hash for privacy
                      Digest::SHA256.hexdigest(report.target.name)[0, 8]
      else
                      report.target&.name&.parameterize || "unknown"
      end
      log_filename = "#{report.uuid}_#{target_name}.log"
      log_path.join(log_filename)
    end

    # Find an existing log file for a report across all date directories.
    # Used by persist_existing_logs when a resumed scan may have crossed a
    # date boundary (log created yesterday, resumed today).
    def find_existing_log_for_report(report)
      scans_dir = Rails.root.join("storage/logs/scans")
      return nil unless scans_dir.exist?

      pattern = scans_dir.join("**", "#{report.uuid}_*.log")
      matches = Dir.glob(pattern)
      return nil if matches.empty?

      # Return the most recently modified match
      Pathname.new(matches.max_by { |f| File.mtime(f) })
    end

    def rails_log_path
      path = Rails.root.join("storage/logs/rails")
      FileUtils.mkdir_p(path)
      path
    end

    def base_log_path
      path = Rails.root.join("storage/logs")
      FileUtils.mkdir_p(path)
      path
    end

    def log_directories
      [
        rails_log_path,
        Rails.root.join("storage/logs/scans"),
        base_log_path
      ]
    end

    def ensure_log_directories_exist
      log_directories.each do |dir|
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      end
    end
  end
end
