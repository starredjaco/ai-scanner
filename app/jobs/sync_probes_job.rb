class SyncProbesJob < ApplicationJob
  queue_as :default
  # Advisory lock key for preventing concurrent sync execution
  SYNC_LOCK_KEY = 0x5359_4E43_5052_4F42  # "SYNCPROB" in hex

  def perform
    # Use PostgreSQL advisory lock to prevent concurrent execution
    # This prevents race conditions where multiple SyncProbesJob instances
    # could run simultaneously and cause probes to be missed by AutoUpdateScanProbesJob
    lock_acquired = ActiveRecord::Base.connection.execute(
      "SELECT pg_try_advisory_lock(#{SYNC_LOCK_KEY})"
    ).first["pg_try_advisory_lock"]

    unless lock_acquired
      Rails.logger.info "[SyncProbesJob] Another sync is already in progress, skipping"
      return
    end

    begin
      perform_sync
    ensure
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{SYNC_LOCK_KEY})")
    end
  end

  private

  def perform_sync
    # Skip if nothing has changed since last sync
    unless needs_sync?
      Rails.logger.info "[SyncProbesJob] Probe data unchanged since last sync, skipping"
      return
    end

    # Capture start time for AutoUpdateScanProbesJob (fixes timing bug)
    sync_start_time = Time.current

    had_failures = false

    ProbeSourceRegistry.sources.each do |source_class|
      source = source_class.new
      next unless source.needs_sync?

      result = source.sync(sync_start_time)
      had_failures = true if result && result[:success] == false
    end

    cleanup_detectors

    if had_failures
      Rails.logger.warn "Some probe sources had sync failures — AutoUpdateScanProbesJob will run but affected sources were not fully synced"
    end
    AutoUpdateScanProbesJob.perform_later

    Rails.logger.info "Syncing probes...done"
  end

  def needs_sync?
    ProbeSourceRegistry.sources.any? { |source_class| source_class.new.needs_sync? }
  end

  def cleanup_detectors
    Rails.logger.info "Cleaning up detectors..."

    # Get all detectors that are not referenced by any probes (including deleted detectors)
    unreferenced_detectors = Detector.with_deleted
                                    .left_joins(:probes)
                                    .where(probes: { detector_id: nil })
                                    .distinct

    # Get detectors only referenced by disabled probes (including deleted detectors)
    detectors_with_only_disabled_probes = Detector.with_deleted
                                                 .joins(:probes)
                                                 .where(probes: { enabled: false })
                                                 .where.not(id: Detector.with_deleted
                                                                       .joins(:probes)
                                                                       .where(probes: { enabled: true })
                                                                       .select(:id))
                                                 .distinct

    # Hard delete unreferenced detectors
    deleted_count = 0
    unreferenced_detectors.find_each do |detector|
      Rails.logger.info "Deleting unreferenced detector: #{detector.name} (ID: #{detector.id})"
      detector.destroy!
      deleted_count += 1
    end

    # Soft delete detectors only referenced by disabled probes
    soft_deleted_count = 0
    detectors_with_only_disabled_probes.find_each do |detector|
      unless detector.deleted?
        Rails.logger.info "Soft deleting detector (only referenced by disabled probes): #{detector.name} (ID: #{detector.id})"
        detector.soft_delete!
        soft_deleted_count += 1
      end
    end

    # Restore detectors that are now referenced by enabled probes
    restored_detectors = Detector.deleted_only.joins(:probes).where(probes: { enabled: true }).distinct
    restored_count = 0
    restored_detectors.find_each do |detector|
      Rails.logger.info "Restoring detector (now referenced by enabled probes): #{detector.name} (ID: #{detector.id})"
      detector.restore!
      restored_count += 1
    end

    Rails.logger.info "Detector cleanup complete: #{deleted_count} deleted, #{soft_deleted_count} soft deleted, #{restored_count} restored"
  end
end
