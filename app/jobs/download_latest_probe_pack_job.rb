# frozen_string_literal: true

# No-op stub for OSS mode. Engine overrides with probe pack download logic.
class DownloadLatestProbePackJob < ApplicationJob
  queue_as :low_priority

  def perform = nil
end
