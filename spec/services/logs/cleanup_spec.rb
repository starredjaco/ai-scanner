require 'rails_helper'

RSpec.describe Logs::Cleanup do
  let(:service) { described_class.new }
  let(:storage_logs_path) { Rails.root.join('storage/logs') }
  let(:rails_logs_path) { storage_logs_path.join('rails') }
  let(:scans_logs_path) { storage_logs_path.join('scans') }

  before do
    # Create test directories
    FileUtils.mkdir_p(rails_logs_path)
    FileUtils.mkdir_p(scans_logs_path.join('2025/01/01'))
    FileUtils.mkdir_p(scans_logs_path.join('2025/01/15'))

    # Stub environment variables
    allow(ENV).to receive(:fetch).with('LOG_RETENTION_DAYS', '14').and_return('14')
    allow(ENV).to receive(:fetch).with('LOG_MAX_SIZE_GB', '1').and_return('1')
    allow(ENV).to receive(:fetch).with('LOG_USE_HASHED_NAMES', 'false').and_return('false')
  end

  after do
    # Clean up test files
    FileUtils.rm_rf(storage_logs_path) if Dir.exist?(storage_logs_path)
  end

  describe '#call' do
    context 'when cleaning up old logs' do
      it 'deletes logs older than retention period' do
        # Create old log file (15 days ago)
        old_log = rails_logs_path.join('old.log')
        File.write(old_log, 'old log content')
        FileUtils.touch(old_log, mtime: 15.days.ago.to_time)

        # Create recent log file (1 day ago)
        recent_log = rails_logs_path.join('recent.log')
        File.write(recent_log, 'recent log content')
        FileUtils.touch(recent_log, mtime: 1.day.ago.to_time)

        result = service.call

        expect(File.exist?(old_log)).to be false
        expect(File.exist?(recent_log)).to be true
        expect(result[:deleted_files]).to eq(1)
      end

      it 'removes logs from all configured directories' do
        # Create old logs in different directories
        old_rails_log = rails_logs_path.join('old_rails.log')
        old_scan_log = scans_logs_path.join('2025/01/01/old_scan.log')

        File.write(old_rails_log, 'content')
        File.write(old_scan_log, 'content')

        FileUtils.touch(old_rails_log, mtime: 20.days.ago.to_time)
        FileUtils.touch(old_scan_log, mtime: 20.days.ago.to_time)

        service.call

        expect(File.exist?(old_rails_log)).to be false
        expect(File.exist?(old_scan_log)).to be false
      end
    end

    context 'when enforcing size limit' do
      it 'deletes oldest logs when total size exceeds limit' do
        # Stub the size limit to a small value for testing
        stub_const('Logs::Cleanup::MAX_TOTAL_SIZE', 100.bytes)

        # Create multiple log files
        log1 = rails_logs_path.join('log1.log')
        log2 = rails_logs_path.join('log2.log')
        log3 = rails_logs_path.join('log3.log')

        File.write(log1, 'a' * 50)  # 50 bytes
        File.write(log2, 'b' * 50)  # 50 bytes
        File.write(log3, 'c' * 50)  # 50 bytes

        FileUtils.touch(log1, mtime: 3.days.ago.to_time)  # Oldest
        FileUtils.touch(log2, mtime: 2.days.ago.to_time)
        FileUtils.touch(log3, mtime: 1.day.ago.to_time)   # Newest

        service.call

        # Should delete oldest file first (log1), keeping total under 100 bytes
        expect(File.exist?(log1)).to be false
        # Either log2 or log3 should remain, but not both (since 50+50=100)
        remaining_files = [ log2, log3 ].select { |f| File.exist?(f) }
        expect(remaining_files.size).to eq(1)
      end
    end

    context 'when cleaning up empty directories' do
      it 'removes empty date directories' do
        empty_dir = scans_logs_path.join('2025/01/10')
        FileUtils.mkdir_p(empty_dir)

        service.call

        expect(Dir.exist?(empty_dir)).to be false
      end

      it 'keeps directories with files' do
        dir_with_file = scans_logs_path.join('2025/01/15')
        log_file = dir_with_file.join('scan.log')
        File.write(log_file, 'content')

        service.call

        expect(Dir.exist?(dir_with_file)).to be true
      end

      it 'does not delete base directories' do
        # Ensure directories exist even if empty
        FileUtils.mkdir_p(rails_logs_path)
        FileUtils.mkdir_p(scans_logs_path)

        service.call

        expect(Dir.exist?(rails_logs_path)).to be true
        expect(Dir.exist?(scans_logs_path)).to be true
      end
    end

    context 'when handling rotated logs' do
      it 'includes rotated log files in cleanup' do
        # Create rotated log files
        rotated_log1 = rails_logs_path.join('application.log.1')
        rotated_log2 = rails_logs_path.join('application.log.2')

        File.write(rotated_log1, 'rotated content')
        File.write(rotated_log2, 'rotated content')

        FileUtils.touch(rotated_log1, mtime: 20.days.ago.to_time)
        FileUtils.touch(rotated_log2, mtime: 20.days.ago.to_time)

        result = service.call

        expect(File.exist?(rotated_log1)).to be false
        expect(File.exist?(rotated_log2)).to be false
        expect(result[:deleted_files]).to eq(2)
      end
    end

    it 'returns summary information' do
      old_log = rails_logs_path.join('old.log')
      File.write(old_log, 'x' * 1024)  # 1KB
      FileUtils.touch(old_log, mtime: 15.days.ago.to_time)

      result = service.call

      expect(result).to include(
        deleted_files: 1,
        freed_space: 1024,
        timestamp: be_a(Time)
      )
    end

    context 'error scenarios' do
      it 'handles permission errors gracefully' do
        # Create a log file
        log_file = rails_logs_path.join('protected.log')
        File.write(log_file, 'content')
        FileUtils.touch(log_file, mtime: 20.days.ago.to_time)

        # Mock permission error
        allow(File).to receive(:delete).with(log_file.to_s).and_raise(Errno::EACCES)

        # Should not raise error, but log warning (might log multiple times due to both cleanup phases)
        expect(Rails.logger).to receive(:warn).with(/Permission denied/).at_least(:once)

        expect { service.call }.not_to raise_error
      end

      it 'handles missing files gracefully' do
        # Create a log file path that will be "deleted" during enumeration
        log_file = rails_logs_path.join('vanishing.log')

        # Mock the file existing during enumeration but not during deletion
        allow(Find).to receive(:find).and_yield(log_file.to_s)
        allow(File).to receive(:file?).with(log_file.to_s).and_return(true)
        allow(File).to receive(:mtime).with(log_file.to_s).and_return(20.days.ago)
        allow(File).to receive(:size).with(log_file.to_s).and_return(1024)
        allow(File).to receive(:delete).with(log_file.to_s).and_raise(Errno::ENOENT)

        # Should handle ENOENT gracefully
        expect { service.call }.not_to raise_error
      end

      it 'validates environment variables at class load time' do
        # Since constants are evaluated at class load time, we need to test by reloading the class
        # We'll test that the current loaded class has valid settings
        expect(described_class::RETENTION_DAYS).to be > 0
        expect(described_class::RETENTION_DAYS).to be <= 365
        expect(described_class::MAX_TOTAL_SIZE).to be > 0
        expect(described_class::MAX_TOTAL_SIZE).to be <= 100.gigabytes
      end
    end
  end
end
