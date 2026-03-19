class AutoUpdateScanProbesJob < ApplicationJob
  queue_as :default

  def perform
    last_sync = DataSyncVersion.latest_for_type("probes")
    return unless last_sync

    # Use sync_start to find probes created during sync (fallback to synced_at for old records)
    sync_baseline = if last_sync.metadata&.dig("sync_start")
      Time.zone.parse(last_sync.metadata["sync_start"])
    else
      last_sync.synced_at
    end
    new_probes = Probe.enabled.where("created_at >= ?", sync_baseline)
    return if new_probes.empty?

    # Group new probes by category
    new_generic_ids = new_probes.by_category(:generic).pluck(:id)
    new_cm_ids = new_probes.by_category(:cm).pluck(:id)
    new_hp_ids = new_probes.by_category(:hp).pluck(:id)

    # Update scans for each category
    update_scans_for_category(Scan.auto_updating_generic, new_generic_ids) if new_generic_ids.any?
    update_scans_for_category(Scan.auto_updating_cm, new_cm_ids) if new_cm_ids.any?
    update_scans_for_category(Scan.auto_updating_hp, new_hp_ids) if new_hp_ids.any?

    Rails.logger.info "[AutoUpdateScanProbes] Updated scans with #{new_probes.count} new probes"
  end

  private

  def update_scans_for_category(scans, new_probe_ids)
    # Process scans in batches for efficiency
    # Use includes(:probes) to prevent N+1 queries when accessing probe_ids
    scans.includes(:probes).in_batches(of: 100) do |batch|
      batch.each do |scan|
        begin
          ActiveRecord::Base.transaction do
            # Lock the scan record to prevent concurrent modifications
            scan.lock!

            # Reload probes AFTER acquiring lock to get fresh data
            scan.probes.reload

            # Get existing probe IDs from reloaded association
            existing_probe_ids = scan.probe_ids
            probes_to_add = new_probe_ids - existing_probe_ids

            if probes_to_add.any?
              # Bulk insert only new associations using SQL to avoid DELETE/INSERT pattern
              # This is much more efficient and safer than probe_ids= which deletes all and reinserts
              # Use sanitize_sql_array for SQL injection safety (Brakeman-approved)
              placeholders = probes_to_add.map { "(?, ?)" }.join(", ")
              values = probes_to_add.flat_map { |probe_id| [ scan.id, probe_id ] }
              sql = ActiveRecord::Base.sanitize_sql_array(
                [ "INSERT INTO probes_scans (scan_id, probe_id) VALUES #{placeholders} ON CONFLICT (scan_id, probe_id) DO NOTHING", *values ]
              )
              ActiveRecord::Base.connection.execute(sql)

              # Reload association to reflect changes made by raw SQL
              scan.probes.reload

              # Manually update updated_at timestamp
              scan.update_column(:updated_at, Time.current)

              # Use proper pluralization for log message
              probe_word = probes_to_add.count == 1 ? "probe" : "probes"
              Rails.logger.info "[AutoUpdateScanProbes] Added #{probes_to_add.count} #{probe_word} to scan #{scan.id}"
            end
          end
        rescue ActiveRecord::StatementInvalid, ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked, ActiveRecord::RecordNotFound => e
          # Transaction is automatically rolled back when exception is raised within the block
          # Catch specific database errors that are expected/recoverable:
          # - StatementInvalid: SQL errors or constraint violations
          # - LockWaitTimeout: Lock acquisition timeout
          # - Deadlocked: Database deadlock detected
          # - RecordNotFound: Record was deleted between queries
          Rails.logger.error "[AutoUpdateScanProbes] Failed to update scan #{scan.id}: #{e.class.name} - #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
        end
      end
    end
  end
end
