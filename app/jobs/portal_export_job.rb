# frozen_string_literal: true

# No-op stub for OSS mode. Engine overrides this with full portal export logic.
class PortalExportJob < ApplicationJob
  queue_as :low_priority

  limits_concurrency to: 1, key: -> { "portal_export" }, on_conflict: :discard

  def perform = nil
end
