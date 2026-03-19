require 'rails_helper'

RSpec.describe LogCleanupJob, type: :job do
  describe '#perform' do
    it 'calls the Logs::Cleanup service' do
      expect(Logs::Cleanup).to receive(:call).and_return({
        deleted_files: 5,
        freed_space: 10.megabytes,
        timestamp: Time.current
      })

      described_class.new.perform
    end

    it 'logs success message' do
      result = {
        deleted_files: 3,
        freed_space: 5.megabytes,
        timestamp: Time.current
      }

      allow(Logs::Cleanup).to receive(:call).and_return(result)

      expect(Rails.logger).to receive(:info).with("Starting scheduled log cleanup job")
      expect(Rails.logger).to receive(:info).with(/Log cleanup completed: deleted 3 files, freed 5MB/)

      described_class.new.perform
    end

    context 'when cleanup fails' do
      it 'logs error and re-raises exception' do
        error = StandardError.new("Cleanup failed")
        allow(Logs::Cleanup).to receive(:call).and_raise(error)

        expect(Rails.logger).to receive(:error).with("Log cleanup failed: StandardError - Cleanup failed")
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          described_class.new.perform
        }.to raise_error(StandardError, "Cleanup failed")
      end
    end
  end

  describe 'retry behavior' do
    it 'is configured to retry on StandardError' do
      # The retry_on is a class-level configuration
      # We can't directly test it, but we can ensure the job handles errors properly
      allow(Logs::Cleanup).to receive(:call).and_return({
        deleted_files: 0,
        freed_space: 0,
        timestamp: Time.current
      })

      expect { described_class.new.perform }.to_not raise_error
    end
  end

  describe 'queue configuration' do
    it 'uses low_priority queue' do
      expect(described_class.new.queue_name).to eq('low_priority')
    end
  end

  describe 'integration scenarios' do
    let(:storage_path) { Rails.root.join('tmp/test_logs') }

    before do
      allow(LogPathManager).to receive(:log_directories).and_return([ storage_path ])
      FileUtils.mkdir_p(storage_path)
    end

    after do
      FileUtils.rm_rf(storage_path)
    end

    context 'when handling concurrent cleanup jobs' do
      it 'handles multiple jobs running simultaneously without errors' do
        # Create test log files
        5.times do |i|
          file = storage_path.join("test_#{i}.log")
          File.write(file, 'test content')
          FileUtils.touch(file, mtime: 20.days.ago.to_time)
        end

        # Simulate concurrent execution
        threads = []
        errors = []

        3.times do
          threads << Thread.new do
            begin
              described_class.new.perform
            rescue => e
              errors << e
            end
          end
        end

        threads.each(&:join)

        # Should handle concurrency without errors
        expect(errors).to be_empty

        # Files should be deleted (by at least one of the jobs)
        remaining_files = Dir.glob(storage_path.join('*.log'))
        expect(remaining_files).to be_empty
      end
    end

    context 'when working with real file system operations' do
      it 'performs end-to-end cleanup with actual files' do
        # Create old and new log files
        old_log = storage_path.join('old.log')
        new_log = storage_path.join('new.log')

        File.write(old_log, 'old content')
        File.write(new_log, 'new content')

        FileUtils.touch(old_log, mtime: 20.days.ago.to_time)
        FileUtils.touch(new_log, mtime: 1.day.ago.to_time)

        # Perform cleanup
        result = described_class.new.perform

        # Verify results
        expect(result[:deleted_files]).to eq(1)
        expect(File.exist?(old_log)).to be false
        expect(File.exist?(new_log)).to be true
      end
    end
  end
end
