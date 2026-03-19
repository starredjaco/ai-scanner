# Engine extension point — no-op in the base application.
# Vendored engines can override this job to generate variant reports.
class GenerateVariantReportsJob < ApplicationJob
  queue_as :default

  def perform(*) = nil
end
