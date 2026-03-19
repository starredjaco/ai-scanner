# frozen_string_literal: true

module Monitoring
  # Used when monitoring is disabled or no provider is configured
  class NullAdapter < Adapter
    def transaction(name, type)
      yield if block_given?
    end

    def set_label(key, value)
      # intentionally empty
    end

    def set_labels(labels)
      # intentionally empty
    end

    def set_user(user)
      # intentionally empty
    end

    def current_trace_id
      nil
    end

    def trace_context
      {}
    end

    def active?
      false
    end

    def service_name
      "scanner"
    end

    def report_event(message, context = {})
      # intentionally empty
    end
  end
end
