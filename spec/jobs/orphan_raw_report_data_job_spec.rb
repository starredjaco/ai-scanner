# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrphanRawReportDataJob, type: :job do
  let(:target) { create(:target) }
  let(:scan) { create(:complete_scan) }
  let(:job_instance) { described_class.new }

  before do
    allow_any_instance_of(ToastNotifier).to receive(:call)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    # Stub the Solid Queue lookup - in test env we don't have Solid Queue tables
    # Default: return empty set (no pending jobs found)
    allow_any_instance_of(described_class).to receive(:find_report_ids_with_pending_jobs).and_return(Set.new)
  end

  describe "#perform" do
    describe "orphan detection" do
      it "recovers raw_report_data older than threshold without pending job" do
        report = create(:report, target: target, scan: scan, status: :failed)
        # Create orphaned raw_report_data (old, no job)
        orphan = create(:raw_report_data, report: report, status: :pending)
        orphan.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.to have_enqueued_job(ProcessReportJob).with(report.id)
      end

      it "does not recover raw_report_data within threshold" do
        report = create(:report, target: target, scan: scan, status: :failed)
        # Recent raw_report_data (within threshold)
        recent = create(:raw_report_data, report: report, status: :pending)
        recent.update_column(:created_at, 2.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data with existing pending job" do
        report = create(:report, target: target, scan: scan, status: :failed)
        orphan = create(:raw_report_data, report: report, status: :pending)
        orphan.update_column(:created_at, 10.minutes.ago)

        # Mock that there's already a pending job for this report
        allow_any_instance_of(described_class).to receive(:find_report_ids_with_pending_jobs)
          .and_return(Set.new([ report.id ]))

        # Should not enqueue another job
        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data in processing status" do
        report = create(:report, target: target, scan: scan, status: :failed)
        processing = create(:raw_report_data, report: report, status: :processing)
        processing.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data for running reports (JournalSync in progress)" do
        report = create(:report, target: target, scan: scan, status: :running)
        raw_data = create(:raw_report_data, report: report, status: :pending)
        raw_data.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data for starting reports" do
        report = create(:report, target: target, scan: scan, status: :starting)
        raw_data = create(:raw_report_data, report: report, status: :pending)
        raw_data.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data for pending reports (awaiting retry)" do
        report = create(:report, target: target, scan: scan, status: :pending)
        raw_data = create(:raw_report_data, report: report, status: :pending)
        raw_data.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data for interrupted reports (awaiting retry)" do
        report = create(:report, target: target, scan: scan, status: :interrupted)
        raw_data = create(:raw_report_data, report: report, status: :pending)
        raw_data.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end

      it "does not recover raw_report_data for stopped reports (user-cancelled)" do
        report = create(:report, target: target, scan: scan, status: :stopped)
        raw_data = create(:raw_report_data, report: report, status: :pending)
        raw_data.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(ProcessReportJob)
      end
    end

    describe "multiple orphans" do
      it "recovers multiple orphaned records" do
        report1 = create(:report, target: target, scan: scan, status: :failed)
        report2 = create(:report, target: target, scan: scan, status: :failed)

        orphan1 = create(:raw_report_data, report: report1, status: :pending)
        orphan1.update_column(:created_at, 10.minutes.ago)

        orphan2 = create(:raw_report_data, report: report2, status: :pending)
        orphan2.update_column(:created_at, 10.minutes.ago)

        expect {
          described_class.new.perform
        }.to have_enqueued_job(ProcessReportJob).exactly(2).times
      end

      it "recovers mix of orphaned and normal records correctly" do
        orphan_report = create(:report, target: target, scan: scan, status: :failed)
        recent_report = create(:report, target: target, scan: scan, status: :failed)

        orphan = create(:raw_report_data, report: orphan_report, status: :pending)
        orphan.update_column(:created_at, 10.minutes.ago)

        recent = create(:raw_report_data, report: recent_report, status: :pending)
        recent.update_column(:created_at, 2.minutes.ago)

        expect {
          described_class.new.perform
        }.to have_enqueued_job(ProcessReportJob).with(orphan_report.id).exactly(:once)
      end
    end

    describe "error handling" do
      it "continues processing other orphans when one fails" do
        report1 = create(:report, target: target, scan: scan, status: :failed)
        report2 = create(:report, target: target, scan: scan, status: :failed)

        orphan1 = create(:raw_report_data, report: report1, status: :pending)
        orphan1.update_column(:created_at, 10.minutes.ago)

        orphan2 = create(:raw_report_data, report: report2, status: :pending)
        orphan2.update_column(:created_at, 10.minutes.ago)

        # Make the first enqueue fail
        call_count = 0
        allow(ProcessReportJob).to receive(:perform_later) do |_id|
          call_count += 1
          raise "Test error" if call_count == 1
          # Let second call through
        end

        # Should not raise, should continue to second orphan
        expect { described_class.new.perform }.not_to raise_error
        expect(call_count).to eq(2)
      end

      it "logs errors when recovery fails" do
        report = create(:report, target: target, scan: scan, status: :failed)
        orphan = create(:raw_report_data, report: report, status: :pending)
        orphan.update_column(:created_at, 10.minutes.ago)

        allow(ProcessReportJob).to receive(:perform_later).and_raise("Test error")

        # Allow other logging but expect error log
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:error).with(/Failed to recover report_id=#{report.id}/)

        described_class.new.perform
      end
    end

    describe "logging" do
      it "logs info when orphans are recovered" do
        report = create(:report, target: target, scan: scan, status: :failed)
        orphan = create(:raw_report_data, report: report, status: :pending)
        orphan.update_column(:created_at, 10.minutes.ago)

        # Allow other info logging but expect the recovery message
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/Recovered 1 orphaned record/).at_least(:once)

        described_class.new.perform
      end

      it "logs debug when no orphans found" do
        # Allow all other logging
        allow(Rails.logger).to receive(:debug).and_call_original
        expect(Rails.logger).to receive(:debug).with(/No orphaned records found/)

        described_class.new.perform
      end
    end
  end

  describe "constants" do
    it "has 5 minute orphan threshold" do
      expect(described_class::ORPHAN_THRESHOLD).to eq(5.minutes)
    end
  end

  describe "queue configuration" do
    it "uses default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe "concurrency configuration" do
    it "has limits_concurrency configured" do
      expect(described_class.concurrency_key).to be_present
    end
  end

  describe "integration with ProcessReportJob" do
    it "enqueues ProcessReportJob for orphans (ProcessReportJob handles deduplication)" do
      report = create(:report, target: target, scan: scan, status: :failed)

      # Create orphaned data
      orphan = create(:raw_report_data, report: report, status: :pending)
      orphan.update_column(:created_at, 10.minutes.ago)

      # Should enqueue the job - deduplication happens at execution time via limits_concurrency
      expect {
        described_class.new.perform
      }.to have_enqueued_job(ProcessReportJob).with(report.id)
    end
  end

  describe "#find_report_ids_with_pending_jobs" do
    # Test the Solid Queue query logic separately (integration test)
    # Skip this test in environments without Solid Queue tables
    it "extracts report IDs from job arguments" do
      job = described_class.new

      # Test the argument extraction method
      args = { "arguments" => [ 123 ] }
      result = job.send(:extract_report_id_from_arguments, args)
      expect(result).to eq(123)

      # Test with JSON string
      json_args = '{"arguments": [456]}'
      result = job.send(:extract_report_id_from_arguments, json_args)
      expect(result).to eq(456)
    end

    it "handles malformed arguments gracefully" do
      job = described_class.new

      # Test with nil
      result = job.send(:extract_report_id_from_arguments, nil)
      expect(result).to be_nil

      # Test with empty hash
      result = job.send(:extract_report_id_from_arguments, {})
      expect(result).to be_nil

      # Test with invalid JSON
      allow(Rails.logger).to receive(:warn)
      result = job.send(:extract_report_id_from_arguments, "invalid json")
      expect(result).to be_nil
    end
  end
end
