require 'rails_helper'

RSpec.describe AutoUpdateScanProbesJob, type: :job do
  let(:target) { create(:target) }
  let!(:old_generic_probe) { create(:probe, name: 'OldGeneric', enabled: true, created_at: 2.days.ago) }
  let!(:old_cm_probe) { create(:probe, name: 'OldCM', enabled: true, created_at: 2.days.ago) }
  let!(:old_hp_probe) { create(:probe, name: 'OldHP', enabled: true, created_at: 2.days.ago) }

  let!(:new_generic_probe) { create(:probe, name: 'NewGeneric', enabled: true, created_at: Time.current) }
  let!(:new_cm_probe) { create(:probe, name: 'NewCM', enabled: true, created_at: Time.current) }
  let!(:new_hp_probe) { create(:probe, name: 'NewHP', enabled: true, created_at: Time.current) }

  let!(:last_sync) do
    create(:data_sync_version,
      sync_type: 'probes',
      synced_at: 1.day.ago,
      metadata: { 'sync_start' => 2.days.ago.iso8601(6) })
  end

  describe '#perform' do
    context 'when no last sync exists' do
      before { DataSyncVersion.destroy_all }

      it 'returns early without processing' do
        expect(Rails.logger).not_to receive(:info)
        described_class.new.perform
      end
    end

    context 'when no new probes exist' do
      before do
        Probe.where('created_at >= ?', last_sync.synced_at).destroy_all
      end

      it 'returns early without processing' do
        expect(Rails.logger).not_to receive(:info)
        described_class.new.perform
      end
    end

    context 'with new probes and auto-updating scans' do
      let!(:generic_scan) do
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_generic_probe ]
        scan.save!
        scan.update!(auto_update_generic: true)
        scan
      end

      let!(:cm_scan) do
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_cm_probe ]
        scan.save!
        scan.update!(auto_update_cm: true)
        scan
      end

      let!(:hp_scan) do
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_hp_probe ]
        scan.save!
        scan.update!(auto_update_hp: true)
        scan
      end

      it 'adds new probes to corresponding auto-updating scans' do
        described_class.new.perform

        expect(generic_scan.reload.probes).to include(old_generic_probe, new_generic_probe)
        expect(cm_scan.reload.probes).to include(old_cm_probe, new_cm_probe)
        expect(hp_scan.reload.probes).to include(old_hp_probe, new_hp_probe)
      end

      it 'logs successful updates' do
        expect(Rails.logger).to receive(:info).with(/\[AutoUpdateScanProbes\] Updated scans with \d+ new probes/)
        expect(Rails.logger).to receive(:info).with(a_string_matching(/\[AutoUpdateScanProbes\] Added \d+ probes? to scan #{generic_scan.id}/))
        expect(Rails.logger).to receive(:info).with(a_string_matching(/\[AutoUpdateScanProbes\] Added \d+ probes? to scan #{cm_scan.id}/))
        expect(Rails.logger).to receive(:info).with(a_string_matching(/\[AutoUpdateScanProbes\] Added \d+ probes? to scan #{hp_scan.id}/))

        described_class.new.perform
      end

      it 'updates the scan timestamps' do
        freeze_time do
          original_time = generic_scan.updated_at

          travel 1.minute
          described_class.new.perform

          expect(generic_scan.reload.updated_at).to be > original_time
        end
      end

      it 'does not disable auto-update flags' do
        described_class.new.perform

        expect(generic_scan.reload.auto_update_generic).to be true
        expect(cm_scan.reload.auto_update_cm).to be true
        expect(hp_scan.reload.auto_update_hp).to be true
      end
    end

    context 'with mixed category scan' do
      let!(:mixed_scan) do
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_generic_probe, old_cm_probe ]
        scan.save!
        scan.update!(auto_update_generic: true, auto_update_cm: true)
        scan
      end

      it 'adds probes from multiple categories' do
        described_class.new.perform

        expect(mixed_scan.reload.probes).to include(
          old_generic_probe, old_cm_probe,
          new_generic_probe, new_cm_probe
        )
      end
    end

    context 'with non-auto-updating scan' do
      let!(:manual_scan) do
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_generic_probe ]
        scan.save!
        scan
      end

      it 'does not add new probes' do
        described_class.new.perform

        expect(manual_scan.reload.probes).to eq([ old_generic_probe ])
      end
    end

    context 'when sync_start is present in metadata' do
      before do
        # Clear existing sync to avoid conflicts
        DataSyncVersion.destroy_all
      end

      let!(:last_sync_with_start) do
        create(:data_sync_version,
          sync_type: 'probes',
          synced_at: 1.minute.ago,
          metadata: { 'sync_start' => 5.minutes.ago.iso8601(6) })
      end

      let!(:probe_before_sync) { create(:probe, name: 'BeforeSyncProbe', enabled: true, created_at: 10.minutes.ago) }
      let!(:probe_during_sync) { create(:probe, name: 'DuringSyncProbeHP', enabled: true, created_at: 3.minutes.ago) }
      let!(:probe_after_sync) { create(:probe, name: 'AfterSyncProbeHP', enabled: true, created_at: 30.seconds.ago) }

      let!(:hp_scan) do
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_hp_probe ]
        scan.save!
        scan.update!(auto_update_hp: true)
        scan
      end

      it 'uses sync_start to find probes created during sync' do
        described_class.new.perform

        # Should pick up probe created at 3 minutes ago (between 5 min sync_start and 1 min synced_at)
        expect(hp_scan.reload.probes).to include(probe_during_sync)

        # Should NOT pick up probe from 10 minutes ago (before sync_start)
        expect(hp_scan.reload.probes).not_to include(probe_before_sync)

        # Should pick up probe from 30 seconds ago (after synced_at)
        expect(hp_scan.reload.probes).to include(probe_after_sync)
      end
    end

    context 'when sync_start is missing (old records)' do
      before do
        # Clear existing sync to avoid conflicts
        DataSyncVersion.destroy_all
      end

      let!(:last_sync_without_start) do
        create(:data_sync_version,
          sync_type: 'probes',
          synced_at: 1.day.ago,
          metadata: {})  # No sync_start
      end

      it 'falls back to using synced_at' do
        # This ensures backward compatibility
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    describe 'timing boundary - critical bug fix scenario' do
      it 'finds probes created between sync_start and synced_at' do
        # This test verifies the fix for the timing bug where probes
        # created during SyncProbesJob were never picked up

        # Clear existing sync to avoid conflicts
        DataSyncVersion.destroy_all

        sync_start_time = 5.minutes.ago
        probe_creation_time = 3.minutes.ago
        synced_at_time = 1.minute.ago

        # Create the DataSyncVersion as SyncProbesJob would
        critical_sync = create(:data_sync_version,
          sync_type: 'probes',
          synced_at: synced_at_time,
          metadata: { 'sync_start' => sync_start_time.iso8601(6) })

        # Create probe at the critical time (between sync_start and synced_at)
        critical_probe = create(:probe,
          name: 'CriticalProbeHP',
          enabled: true,
          created_at: probe_creation_time)

        # Create scan with auto-update
        scan = build(:scan)
        scan.targets = [ target ]
        scan.probes = [ old_hp_probe ]
        scan.save!
        scan.update!(auto_update_hp: true)

        # Run the job
        described_class.new.perform

        # CRITICAL ASSERTION: Probe created at T-3min should be picked up
        # because it's >= sync_start (T-5min), even though it's < synced_at (T-1min)
        expect(scan.reload.probes).to include(critical_probe)
      end
    end
  end

  describe '#update_scans_for_category' do
    let(:job) { described_class.new }

    let!(:scan1) do
      scan = build(:scan)
      scan.targets = [ target ]
      scan.probes = [ old_generic_probe ]
      scan.save!
      scan.update!(auto_update_generic: true)
      scan
    end

    let!(:scan2) do
      scan = build(:scan)
      scan.targets = [ target ]
      scan.probes = [ old_generic_probe ]
      scan.save!
      scan.update!(auto_update_generic: true)
      scan
    end

    it 'processes scans in batches for efficiency' do
      scans = Scan.auto_updating_generic
      expect(scans).to receive(:in_batches).with(of: 100).and_call_original

      job.send(:update_scans_for_category, scans, [ new_generic_probe.id ])
    end

    it 'adds new probes without removing existing ones' do
      job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])

      expect(scan1.reload.probes).to match_array([ old_generic_probe, new_generic_probe ])
      expect(scan2.reload.probes).to match_array([ old_generic_probe, new_generic_probe ])
    end

    it 'does not add duplicate probes' do
      # Add new probe manually first
      scan1.probes << new_generic_probe

      job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])

      # Should still only have 2 probes
      expect(scan1.reload.probes.count).to eq(2)
      expect(scan2.reload.probes).to match_array([ old_generic_probe, new_generic_probe ])
    end

    it 'uses SQL INSERT for efficiency' do
      # Expect a raw SQL INSERT statement with type-casted integers
      expect(ActiveRecord::Base.connection).to receive(:execute)
        .with(/INSERT INTO probes_scans.*VALUES.*ON CONFLICT/)
        .twice  # Once for each scan

      job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])
    end

    it 'does not trigger check_probe_changes callback' do
      # Raw SQL and update_column bypass ActiveRecord callbacks entirely
      job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])

      expect(scan1.reload.auto_update_generic).to be true
    end

    context 'with concurrent modifications' do
      it 'handles duplicates silently with ON CONFLICT DO NOTHING' do
        # Manually add the probe first to simulate concurrent addition
        scan1.probes << new_generic_probe

        # Should not raise error, ON CONFLICT DO NOTHING handles it
        expect {
          job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])
        }.not_to raise_error

        # Scan should still only have 2 probes (old + new, no duplicates)
        expect(scan1.reload.probes.count).to eq(2)
      end
    end

    context 'with database errors' do
      it 'logs errors and continues processing other scans' do
        # Simulate a database error on the first scan by stubbing any instance
        # Use ActiveRecord::RecordNotFound which is in the list of caught exceptions
        call_count = 0
        allow_any_instance_of(Scan).to receive(:lock!) do
          call_count += 1
          raise ActiveRecord::RecordNotFound.new("Database error") if call_count == 1
        end

        expect(Rails.logger).to receive(:error).with(a_string_matching(/\[AutoUpdateScanProbes\] Failed to update scan \d+: ActiveRecord::RecordNotFound - Database error/))
        expect(Rails.logger).to receive(:error).at_least(:once)  # Backtrace logging
        expect(Rails.logger).to receive(:info).with(a_string_matching(/\[AutoUpdateScanProbes\] Added \d+ probes? to scan \d+/))

        job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])

        # At least one scan should be updated (the one that didn't fail)
        updated_scans = [ scan1.reload, scan2.reload ].select { |s| s.probes.include?(new_generic_probe) }
        expect(updated_scans.size).to eq(1)
      end
    end

    context 'with empty probe list' do
      it 'does not update any scans' do
        original_count1 = scan1.probes.count
        original_count2 = scan2.probes.count

        job.send(:update_scans_for_category, Scan.auto_updating_generic, [])

        expect(scan1.reload.probes.count).to eq(original_count1)
        expect(scan2.reload.probes.count).to eq(original_count2)
      end
    end

    context 'with large batch of scans' do
      before do
        # Create 150 scans to test batching (batch size is 100)
        150.times do
          scan = build(:scan)
          scan.targets = [ target ]
          scan.probes = [ old_generic_probe ]
          scan.save!
          scan.update!(auto_update_generic: true)
        end
      end

      it 'processes all scans in multiple batches' do
        job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])

        # All scans should have the new probe
        Scan.auto_updating_generic.each do |scan|
          expect(scan.probes).to include(new_generic_probe)
        end
      end
    end

    context 'with transaction rollback' do
      it 'ensures atomic updates per scan' do
        # Simulate failure after lock but before insert
        # Use ActiveRecord::StatementInvalid which is in the list of caught exceptions
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::StatementInvalid.new("Simulated error"))

        expect {
          job.send(:update_scans_for_category, Scan.auto_updating_generic, [ new_generic_probe.id ])
        }.not_to change { scan1.reload.probes.count }
      end
    end
  end

  describe 'integration with SyncProbesJob' do
    let(:probes_json) do
      {
        "probe1" => {
          "guid" => "guid-1",
          "summary" => "Test probe 1",
          "release_date" => "2023-01-01",
          "modified_date" => "2023-01-01",
          "disclosure_status" => "0-day",
          "description" => "Description 1",
          "techniques" => [ "technique1" ],
          "social_impact_score" => 1,
          "detector" => "detector1",
          "scores" => {},
          "prompts" => []
        }
      }
    end

    let(:taxonomies_json) do
      [
        {
          "name" => "category1",
          "children" => [
            {
              "children" => [
                { "name" => "technique1" }
              ]
            }
          ]
        }
      ]
    end

    before do
      # Stub probe sources to return a simple sync
      source_instance = instance_double("GarakCommunityProbeSource", needs_sync?: true, sync: { success: true })
      allow(ProbeSourceRegistry).to receive(:sources).and_return([ GarakCommunityProbeSource ])
      allow(GarakCommunityProbeSource).to receive(:new).and_return(source_instance)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
    end

    it 'is triggered after SyncProbesJob completes' do
      expect(AutoUpdateScanProbesJob).to receive(:perform_later)

      SyncProbesJob.new.perform
    end
  end
end
