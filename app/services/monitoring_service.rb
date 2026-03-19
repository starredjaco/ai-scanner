# frozen_string_literal: true

# MonitoringService provides a unified interface for application monitoring
# It abstracts the underlying monitoring provider (Elastic APM, Datadog, etc.)
# allowing easy swapping of monitoring backends without code changes
#
# Usage:
#   MonitoringService.transaction("operation_name", "background") do
#     # your code here
#     MonitoringService.set_label(:user_id, 123)
#   end
#
# Configuration:
#   Set MONITORING_PROVIDER environment variable to select a provider.
#   Add providers by implementing Monitoring::Adapter subclass.
#
class MonitoringService
  class << self
    MUTEX = Mutex.new

    # Thread-safe for multi-threaded Puma
    # @return [Monitoring::Adapter] The active adapter
    def adapter
      return @adapter if @adapter

      MUTEX.synchronize do
        @adapter ||= create_adapter
      end
    end

    # Useful for testing
    # Thread-safe
    def reset!
      MUTEX.synchronize do
        @adapter = nil
      end
    end

    # Wrap a block of code in a transaction
    # @param name [String] Name of the transaction
    # @param type [String] Type of transaction (e.g., "background", "custom", "request")
    # @yield The block to execute within the transaction context
    # @return The result of the block
    def transaction(name, type, &block)
      adapter.transaction(name, type, &block)
    end

    # Set a label on the current transaction
    # @param key [Symbol, String] Label key
    # @param value [Object] Label value
    def set_label(key, value)
      adapter.set_label(key, value)
    end

    # Set multiple labels at once
    # @param labels [Hash] Hash of label key-value pairs
    def set_labels(labels)
      adapter.set_labels(labels)
    end

    # Get the current trace ID
    # @return [String, nil] The trace ID, or nil if no active transaction
    def current_trace_id
      adapter.current_trace_id
    end

    # Get trace context for propagating to child processes
    # @return [Hash] Hash containing trace context environment variables
    def trace_context
      adapter.trace_context
    end

    # Check if monitoring is currently active
    # @return [Boolean] true if monitoring is enabled and active
    def active?
      adapter.active?
    end

    # Get the service name
    # @return [String] The service name
    def service_name
      adapter.service_name
    end

    # Set the current user context for APM tracking
    # @param user [User, nil] The current user object
    def set_user(user)
      adapter.set_user(user)
    end

    # Measure execution time and record as label
    # @param label_name [Symbol, String] Label name for the duration metric
    # @yield The block to measure
    # @return The result of the block
    def measure(label_name, &block)
      return yield unless active?

      start_time = Time.current
      result = yield
      duration_ms = ((Time.current - start_time) * 1000).round(2)
      set_label(label_name, duration_ms)
      result
    end

    # Record a metric with common pattern
    # @param metric_type [String] Type of metric being recorded
    # @param labels [Hash] Additional labels to set
    def record_metric(metric_type, labels = {})
      return unless active?

      set_label(:metric_type, metric_type)
      set_labels(labels)
    end

    # Report an explicit event/message to the monitoring system
    # This creates a queryable event that can be used for alerting and visualization
    # @param message [String] The event message
    # @param context [Hash] Additional context/labels for the event
    def report_event(message, context = {})
      adapter.report_event(message, context)
    end

    # Prevents monitoring failures from breaking the application
    # @param key [Symbol, String] Label key
    # @param value [Object] Label value
    def safe_set_label(key, value)
      set_label(key, value)
    rescue StandardError => e
      Rails.logger.warn("[Monitoring] Failed to set label #{key}: #{e.message}")
    end

    # @param labels [Hash] Hash of label key-value pairs
    def safe_set_labels(labels)
      set_labels(labels)
    rescue StandardError => e
      Rails.logger.warn("[Monitoring] Failed to set labels: #{e.message}")
    end

    private

    # @return [Monitoring::Adapter] The configured adapter or NullAdapter
    def create_adapter
      require_relative "monitoring/null_adapter"
      Monitoring::NullAdapter.new
    end

    # @return [Symbol] The provider name
    def determine_provider
      # Explicit provider setting takes precedence
      if ENV["MONITORING_PROVIDER"].present?
        return ENV["MONITORING_PROVIDER"].downcase.to_sym
      end

      :null
    end
  end
end
