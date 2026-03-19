# frozen_string_literal: true

module Monitoring
  # Base adapter class for monitoring implementations
  # Subclasses should implement these methods for specific monitoring providers
  class Adapter
    # Wrap a block of code in a transaction/span
    # @param name [String] Name of the transaction
    # @param type [String] Type of transaction (e.g., "background", "custom", "request")
    # @yield The block to execute within the transaction context
    # @return The result of the block
    def transaction(name, type)
      raise NotImplementedError, "#{self.class} must implement #transaction"
    end

    # Set a label/tag on the current transaction
    # Labels are indexed, searchable metadata
    # @param key [Symbol, String] Label key
    # @param value [Object] Label value (will be converted to string)
    def set_label(key, value)
      raise NotImplementedError, "#{self.class} must implement #set_label"
    end

    # Set multiple labels at once
    # @param labels [Hash] Hash of label key-value pairs
    def set_labels(labels)
      labels.each { |key, value| set_label(key, value) }
    end

    # Get the current trace ID for distributed tracing
    # @return [String, nil] The trace ID, or nil if no active transaction
    def current_trace_id
      raise NotImplementedError, "#{self.class} must implement #current_trace_id"
    end

    # Get trace context for propagating to child processes
    # @return [Hash] Hash containing trace context keys (e.g., TRACEPARENT, TRACESTATE, TRACE_ID)
    def trace_context
      raise NotImplementedError, "#{self.class} must implement #trace_context"
    end

    # Check if monitoring is currently active
    # @return [Boolean] true if monitoring is enabled and active
    def active?
      false
    end

    # Get the service name for this monitoring instance
    # @return [String] The service name
    def service_name
      raise NotImplementedError, "#{self.class} must implement #service_name"
    end

    # Report an explicit event/message to the monitoring system
    # This creates a queryable event that can be used for alerting and visualization
    # @param message [String] The event message
    # @param context [Hash] Additional context/labels for the event
    def report_event(message, context = {})
      raise NotImplementedError, "#{self.class} must implement #report_event"
    end
  end
end
