# frozen_string_literal: true

# Job responsible for running scheduled scans with atomic claiming.
# Prevents race conditions in multi-pod deployments where multiple pods
# could try to run the same scheduled scan simultaneously.
#
# Uses atomic UPDATE...WHERE pattern to ensure only one pod wins the claim
# for each due scan, preventing duplicate report creation.
#
# @see StartPendingScansJob for similar atomic claiming pattern
class ScheduledScanJob < ApplicationJob
  queue_as :default
  self.log_arguments = false

  def perform
    Scan.due_to_run.includes(:targets).find_each do |scan|
      process_scheduled_scan(scan)
    end
  end

  private

  def process_scheduled_scan(scan)
    next_run = calculate_next_run_for(scan)

    if claim_scan_atomically(scan, next_run)
      Rails.logger.info("[ScheduledScan] Claimed scan #{scan.id} (#{scan.name}), creating reports")
      scan.reload.rerun
    else
      Rails.logger.debug("[ScheduledScan] Scan #{scan.id} already claimed by another process")
    end
  end

  # Calculate next scheduled run using IceCube (same logic as Scan#update_next_scheduled_run)
  def calculate_next_run_for(scan)
    return nil if scan.recurrence.blank?

    schedule = IceCube::Schedule.new(Time.now.utc)
    schedule.add_recurrence_rule(scan.recurrence)
    schedule.next_occurrence.beginning_of_minute
  end

  # Atomic claim: UPDATE only succeeds if scan is still due
  # Returns true if this process won the claim, false otherwise
  def claim_scan_atomically(scan, next_run)
    updated_count = Scan.where(id: scan.id)
                        .where("next_scheduled_run <= ?", Time.now.utc)
                        .update_all(next_scheduled_run: next_run, updated_at: Time.current)
    updated_count.positive?
  end
end
