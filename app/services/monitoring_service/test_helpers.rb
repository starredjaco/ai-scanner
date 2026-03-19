# frozen_string_literal: true

class MonitoringService
  # Test utilities for working with MonitoringService in tests
  # Include this module in your test suite to access monitoring test helpers
  #
  # Usage in RSpec:
  #   RSpec.configure do |config|
  #     config.include MonitoringService::TestHelpers
  #   end
  #
  # Or in individual tests:
  #   include MonitoringService::TestHelpers
  #
  module TestHelpers
    # Stub all monitoring methods to prevent actual monitoring during tests
    # Use this when you don't care about monitoring in a specific test
    #
    # @example
    #   before do
    #     stub_monitoring
    #   end
    #
    #   it "performs action without monitoring" do
    #     MyService.call # monitoring is stubbed, no real APM calls
    #   end
    #
    def stub_monitoring
      allow(MonitoringService).to receive(:transaction).and_yield
      allow(MonitoringService).to receive(:set_label)
      allow(MonitoringService).to receive(:set_labels)
      allow(MonitoringService).to receive(:safe_set_label)
      allow(MonitoringService).to receive(:safe_set_labels)
      allow(MonitoringService).to receive(:record_metric)
      allow(MonitoringService).to receive(:measure).and_yield
      allow(MonitoringService).to receive(:current_trace_id).and_return("test-trace-id")
      allow(MonitoringService).to receive(:trace_context).and_return({})
      allow(MonitoringService).to receive(:active?).and_return(false)
    end

    # Temporarily disable monitoring for the duration of a block
    # Useful for testing code that should work with and without monitoring
    #
    # @example
    #   it "works without monitoring" do
    #     with_monitoring_disabled do
    #       expect(MonitoringService.active?).to be false
    #       MyService.call # runs without monitoring
    #     end
    #   end
    #
    def with_monitoring_disabled(&block)
      original_adapter = MonitoringService.instance_variable_get(:@adapter)
      MonitoringService.instance_variable_set(:@adapter, Monitoring::NullAdapter.new)
      yield
    ensure
      MonitoringService.instance_variable_set(:@adapter, original_adapter)
    end

    # Capture all labels set during a block
    # Returns a hash of all labels that were set
    #
    # @return [Hash] All labels set during the block
    #
    # @example
    #   it "records correct metrics" do
    #     labels = capture_monitoring_labels do
    #       Report.create!(status: :completed)
    #     end
    #
    #     expect(labels[:scan_status]).to eq("completed")
    #     expect(labels[:scan_duration_seconds]).to be > 0
    #   end
    #
    def capture_monitoring_labels
      labels = {}

      allow(MonitoringService).to receive(:set_label) do |key, value|
        labels[key] = value
      end

      allow(MonitoringService).to receive(:set_labels) do |label_hash|
        labels.merge!(label_hash)
      end

      yield

      labels
    end

    # Verify that specific monitoring labels were set
    # Fails if expected labels are not present
    #
    # @param expected_labels [Hash] Labels that should have been set
    #
    # @example
    #   it "sets required labels" do
    #     expect_monitoring_labels(
    #       metric_type: "scan_duration",
    #       scan_status: "completed"
    #     ) do
    #       MyService.record_metrics
    #     end
    #   end
    #
    def expect_monitoring_labels(expected_labels, &block)
      actual_labels = capture_monitoring_labels(&block)

      expected_labels.each do |key, expected_value|
        actual_value = actual_labels[key]

        if expected_value.is_a?(Regexp)
          expect(actual_value).to match(expected_value),
            "Expected label #{key} to match #{expected_value.inspect}, got #{actual_value.inspect}"
        else
          expect(actual_value).to eq(expected_value),
            "Expected label #{key} to be #{expected_value.inspect}, got #{actual_value.inspect}"
        end
      end
    end

    # Mock a monitoring transaction
    # Useful for testing code that requires an active transaction
    #
    # @example
    #   it "records metrics within transaction" do
    #     with_monitoring_transaction("test_operation", "background") do
    #       expect(MonitoringService.current_trace_id).to eq("mocked-trace-id")
    #       MyService.call
    #     end
    #   end
    #
    def with_monitoring_transaction(name, type)
      allow(MonitoringService).to receive(:transaction).and_yield
      allow(MonitoringService).to receive(:current_trace_id).and_return("mocked-trace-id-#{name}")
      allow(MonitoringService).to receive(:active?).and_return(true)

      yield
    end

    # Assert that a transaction was created with specific parameters
    #
    # @example
    #   it "creates correct transaction" do
    #     expect_monitoring_transaction("run_scan", "background") do
    #       RunGarakScan.new(report).call
    #     end
    #   end
    #
    def expect_monitoring_transaction(expected_name, expected_type, &block)
      expect(MonitoringService).to receive(:transaction)
        .with(expected_name, expected_type)
        .and_yield

      block.call
    end

    # Simulate monitoring being enabled
    #
    # @example
    #   it "records metrics when monitoring enabled" do
    #     with_monitoring_enabled do
    #       expect(MonitoringService.active?).to be true
    #     end
    #   end
    #
    def with_monitoring_enabled
      original_adapter = MonitoringService.instance_variable_get(:@adapter)

      # Create a mock adapter that reports as active
      mock_adapter = instance_double(Monitoring::Adapter)
      allow(mock_adapter).to receive(:active?).and_return(true)
      allow(mock_adapter).to receive(:transaction).and_yield
      allow(mock_adapter).to receive(:set_label)
      allow(mock_adapter).to receive(:set_labels)
      allow(mock_adapter).to receive(:current_trace_id).and_return("test-trace-id")
      allow(mock_adapter).to receive(:trace_context).and_return({})
      allow(mock_adapter).to receive(:service_name).and_return("scanner-test")

      MonitoringService.instance_variable_set(:@adapter, mock_adapter)

      yield
    ensure
      MonitoringService.instance_variable_set(:@adapter, original_adapter)
    end
  end
end
