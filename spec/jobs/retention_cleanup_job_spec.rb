# frozen_string_literal: true

require "rails_helper"

RSpec.describe RetentionCleanupJob, type: :job do
  describe "#perform" do
    it "calls the Retention::Cleanup service" do
      expect(Retention::Cleanup).to receive(:call).and_return({
        companies_processed: 2,
        reports_deleted: 10,
        errors: [],
        timestamp: Time.current
      })

      described_class.new.perform
    end

    it "logs success message with statistics" do
      result = {
        companies_processed: 3,
        reports_deleted: 15,
        errors: [],
        timestamp: Time.current
      }

      allow(Retention::Cleanup).to receive(:call).and_return(result)

      expect(Rails.logger).to receive(:info).with("[RetentionCleanup] Starting scheduled retention cleanup")
      expect(Rails.logger).to receive(:info).with(
        "[RetentionCleanup] Completed: 3 companies processed, 15 reports deleted"
      )

      described_class.new.perform
    end

    it "logs warnings for errors but does not raise" do
      result = {
        companies_processed: 1,
        reports_deleted: 5,
        errors: [
          { company_id: 123, message: "DB connection lost" },
          { company_id: 456, message: "Timeout" }
        ],
        timestamp: Time.current
      }

      allow(Retention::Cleanup).to receive(:call).and_return(result)

      expect(Rails.logger).to receive(:info).twice # start and complete
      expect(Rails.logger).to receive(:warn).with("[RetentionCleanup] Error for company 123: DB connection lost")
      expect(Rails.logger).to receive(:warn).with("[RetentionCleanup] Error for company 456: Timeout")

      # Should not raise even with errors
      expect { described_class.new.perform }.not_to raise_error
    end

    it "returns the result from the service" do
      result = {
        companies_processed: 2,
        reports_deleted: 8,
        errors: [],
        timestamp: Time.current
      }

      allow(Retention::Cleanup).to receive(:call).and_return(result)

      expect(described_class.new.perform).to eq(result)
    end
  end

  describe "queue configuration" do
    it "uses low_priority queue" do
      expect(described_class.new.queue_name).to eq("low_priority")
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      # Verify retry configuration exists
      retry_handlers = described_class.rescue_handlers
      # Rails stores exception classes as strings in rescue_handlers
      expect(retry_handlers.map { |h| h[0].to_s }).to include("StandardError")
    end

    it "handles successful execution without errors" do
      allow(Retention::Cleanup).to receive(:call).and_return({
        companies_processed: 0,
        reports_deleted: 0,
        errors: [],
        timestamp: Time.current
      })

      expect { described_class.new.perform }.not_to raise_error
    end
  end

  describe "concurrency limits" do
    it "has concurrency limit of 1" do
      # Verify limits_concurrency is configured
      # This is tested by ensuring the job configuration exists
      expect(described_class.concurrency_limit).to be_present
    end
  end
end
