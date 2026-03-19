require 'rails_helper'

RSpec.describe "Target Soft Delete Integration", type: :model do
  describe "soft delete behavior in context" do
    let(:target) { create(:target) }
    let!(:scan) { create(:complete_scan) }
    let!(:report) { create(:report, target: target, scan: scan) }
    let!(:env_var) { create(:environment_variable, target: target) }

    context "when Target has dependent records" do
      it "preserves all dependent records after soft delete" do
        # Record initial counts
        initial_report_count = Report.count
        initial_env_var_count = EnvironmentVariable.count
        initial_target_count = Target.count

        # Soft delete the target
        target.mark_deleted!

        # Verify soft delete behavior
        expect(Target.count).to eq(initial_target_count - 1) # Excluded from default scope
        expect(Target.with_deleted.count).to eq(initial_target_count) # Still exists in database
        expect(Report.count).to eq(initial_report_count) # Reports preserved
        expect(EnvironmentVariable.count).to eq(initial_env_var_count) # Env vars preserved

        # Verify target is actually soft deleted
        expect(target.deleted?).to be true
        expect(target.deleted_at).to be_present

        # Verify we can still access associations through unscoped queries
        deleted_target = Target.with_deleted.find(target.id)
        expect(deleted_target.reports).to include(report)
        expect(deleted_target.environment_variables).to include(env_var)
      end

      it "allows restoration of soft deleted target with all associations intact" do
        # Soft delete first
        target.mark_deleted!
        expect(Target.all).not_to include(target)

        # Restore the target
        target.restore!

        # Verify restoration
        expect(Target.all).to include(target)
        expect(target.deleted?).to be false
        expect(target.deleted_at).to be_nil

        # Verify associations are still intact
        target.reload
        expect(target.reports).to include(report)
        expect(target.environment_variables).to include(env_var)
      end
    end

    context "ransack filtering" do
      let!(:active_target) { create(:target, name: "Active Target") }
      let!(:deleted_target) { create(:target, :deleted, name: "Deleted Target") }

      it "can filter for deleted targets using ransack" do
        # This simulates what the admin interface does with the deleted_at filter
        search = Target.with_deleted.ransack(deleted_at_not_null: "1")
        results = search.result

        expect(results).to include(deleted_target)
        expect(results).not_to include(active_target)
      end

      it "can filter for active targets using ransack" do
        search = Target.ransack(deleted_at_null: "1")
        results = search.result

        expect(results).to include(active_target)
        expect(results).not_to include(deleted_target)
      end
    end

    context "scope behavior" do
      it "correctly separates active and deleted targets" do
        initial_active_count = Target.count
        initial_deleted_count = Target.deleted.count
        initial_total_count = Target.with_deleted.count

        active_targets = create_list(:target, 3)
        deleted_targets = create_list(:target, 2, :deleted)

        expect(Target.count).to eq(initial_active_count + 3)
        expect(Target.deleted.count).to eq(initial_deleted_count + 2)
        expect(Target.with_deleted.count).to eq(initial_total_count + 5)
      end

      it "maintains proper counts after soft deletions and restorations" do
        initial_active_count = Target.count
        initial_deleted_count = Target.deleted.count
        initial_total_count = Target.with_deleted.count

        active_targets = create_list(:target, 3)
        deleted_targets = create_list(:target, 2, :deleted)

        # Delete one more target
        active_targets.first.mark_deleted!

        expect(Target.count).to eq(initial_active_count + 2) # 2 remaining active from new ones
        expect(Target.deleted.count).to eq(initial_deleted_count + 3) # 2 original + 1 newly deleted
        expect(Target.with_deleted.count).to eq(initial_total_count + 5) # Total unchanged

        # Restore one deleted target
        deleted_targets.first.restore!

        expect(Target.count).to eq(initial_active_count + 3) # 2 + 1 restored from new ones
        expect(Target.deleted.count).to eq(initial_deleted_count + 2) # 3 - 1 restored
        expect(Target.with_deleted.count).to eq(initial_total_count + 5) # Total unchanged
      end
    end
  end
end
