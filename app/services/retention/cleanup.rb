# frozen_string_literal: true

module Retention
  # Delegates report cleanup to the configured retention strategy.
  #
  # OSS default: Retention::SimpleStrategy (fixed 90-day retention)
  # Engine override: engine tier retention (tier-based with grace periods)
  #
  # Usage:
  #   result = Retention::Cleanup.call
  #   # => { companies_processed: 5, reports_deleted: 42, errors: [], timestamp: ... }
  #
  class Cleanup < ApplicationService
    def call
      Scanner.configuration.retention_strategy_class_constant.new.call
    end
  end
end
