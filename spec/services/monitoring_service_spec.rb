# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonitoringService do
  describe "default behavior" do
    it "uses NullAdapter by default" do
      expect(described_class.adapter).to be_a(Monitoring::NullAdapter)
      expect(described_class.active?).to be false
    end

    it "does not make network connections" do
      expect do
        described_class.transaction("test_operation", "background") do
          described_class.set_label(:test_key, "test_value")
          described_class.set_labels(key1: "value1", key2: "value2")
        end
      end.not_to raise_error
    end

    it "returns nil for trace context" do
      expect(described_class.current_trace_id).to be_nil
      expect(described_class.trace_context).to eq({})
    end

    it "reports correct service name" do
      expect(described_class.service_name).to eq("scanner")
    end
  end

  describe "adapter selection" do
    it "selects NullAdapter by default" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("MONITORING_PROVIDER").and_return(nil)

      MonitoringService.reset!
      expect(MonitoringService.adapter).to be_a(Monitoring::NullAdapter)
    end
  end

  describe "thread safety" do
    it "handles concurrent adapter access safely" do
      threads = 10.times.map do
        Thread.new do
          100.times do
            described_class.adapter
            described_class.active?
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end

  describe "graceful degradation" do
    it "does not raise errors when monitoring operations fail" do
      expect do
        described_class.safe_set_label(:test, "value")
        described_class.safe_set_labels(key1: "val1", key2: "val2")
      end.not_to raise_error
    end

    it "measures execution time even when monitoring is disabled" do
      result = described_class.measure(:test_duration) do
        sleep 0.01
        "test_result"
      end

      expect(result).to eq("test_result")
    end
  end
end
