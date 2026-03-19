require "find"

module Logs
  class Cleanup < ApplicationService
    # Default retention period and size limits with validation
    RETENTION_DAYS = begin
      days = ENV.fetch("LOG_RETENTION_DAYS", "14").to_i
      raise ArgumentError, "LOG_RETENTION_DAYS must be positive" if days <= 0
      raise ArgumentError, "LOG_RETENTION_DAYS too large (max 365)" if days > 365
      days
    end

    MAX_TOTAL_SIZE = begin
      size_gb = ENV.fetch("LOG_MAX_SIZE_GB", "1").to_f
      raise ArgumentError, "LOG_MAX_SIZE_GB must be positive" if size_gb <= 0
      raise ArgumentError, "LOG_MAX_SIZE_GB too large (max 100)" if size_gb > 100
      size_gb.gigabytes
    end

    def call
      Rails.logger.info "Starting log cleanup at #{Time.current}"

      # Perform optimized single-pass cleanup
      result = optimized_cleanup

      # Remove empty directories
      cleanup_empty_directories

      Rails.logger.info "Log cleanup completed: deleted #{result[:deleted_files]} files, freed #{result[:freed_space] / 1.megabyte}MB"

      result.merge(timestamp: Time.current)
    end

    private

    def optimized_cleanup
      deleted_count = 0
      freed_space = 0
      cutoff_date = RETENTION_DAYS.days.ago
      log_files_for_size_check = []
      total_size = 0

      # Single traversal to handle both old files and collect size info
      log_directories.each do |dir|
        next unless Dir.exist?(dir)

        Find.find(dir) do |file|
          next unless File.file?(file)
          next unless file.match?(/\.log(\.\d+)?$/)

          begin
            file_mtime = File.mtime(file)
            file_size = File.size(file)

            # Delete old files immediately
            if file_mtime < cutoff_date
              File.delete(file)
              deleted_count += 1
              freed_space += file_size
              Rails.logger.debug "Deleted old log: #{file} (#{file_size / 1024}KB)"
            else
              # Collect info for potential size-based deletion
              log_files_for_size_check << [ file, file_mtime, file_size ]
              total_size += file_size
            end
          rescue Errno::ENOENT
            # File disappeared, continue
          rescue Errno::EACCES => e
            Rails.logger.warn "Permission denied accessing log #{file}: #{e.message}"
          rescue => e
            Rails.logger.warn "Failed to process log #{file}: #{e.message}"
          end
        end
      end

      # Now handle size limit if needed
      if total_size > MAX_TOTAL_SIZE
        Rails.logger.info "Total log size (#{total_size / 1.gigabyte}GB) exceeds limit (#{MAX_TOTAL_SIZE / 1.gigabyte}GB)"

        # Sort by age (oldest first)
        log_files_for_size_check.sort_by! { |_, mtime, _| mtime }

        log_files_for_size_check.each do |file_path, _, file_size|
          break if total_size <= MAX_TOTAL_SIZE

          begin
            File.delete(file_path)
            total_size -= file_size
            deleted_count += 1
            freed_space += file_size
            Rails.logger.debug "Deleted log to enforce size limit: #{file_path} (#{file_size / 1024}KB)"
          rescue Errno::ENOENT
            total_size -= file_size
          rescue => e
            Rails.logger.warn "Failed to delete log file #{file_path}: #{e.message}"
          end
        end
      end

      { deleted_files: deleted_count, freed_space: freed_space }
    end


    def cleanup_empty_directories
      # Clean up empty directories in reverse order (deepest first)
      log_directories.each do |base_dir|
        next unless Dir.exist?(base_dir)

        Dir.glob(File.join(base_dir, "**", "*")).reverse.each do |path|
          next unless File.directory?(path)
          next if path == base_dir.to_s # Don't delete base directories
          # Skip if this path is a parent of any base directory
          next if log_directories.any? { |dir| dir.to_s.start_with?(path) }

          begin
            # Only remove if directory is empty
            Dir.rmdir(path) if Dir.empty?(path)
          rescue Errno::ENOTEMPTY, Errno::ENOTDIR, Errno::ENOENT
            # Directory not empty, not a directory, or doesn't exist - skip
          end
        end
      end

      # Ensure base directories exist
      LogPathManager.ensure_log_directories_exist
    end

    def log_directories
      LogPathManager.log_directories
    end
  end
end
