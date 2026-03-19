require "rails_helper"

RSpec.describe Target, "scheduled scans functionality", type: :model do
  let(:target) { create(:target) }
  let(:probe) { create(:probe) }

  before do
    # Stub garak execution to avoid external dependencies in tests
    allow_any_instance_of(RunGarakScan).to receive(:call)
    allow_any_instance_of(Scan).to receive(:update_next_scheduled_run)
  end

  describe "scans association" do
    it "can have multiple scans" do
      scan1 = create(:complete_scan, name: "First Scan")
      scan2 = create(:complete_scan, name: "Second Scan")

      target.scans << scan1
      target.scans << scan2

      expect(target.scans).to include(scan1, scan2)
      expect(target.scans.count).to eq(2)
    end

    it "maintains bidirectional association" do
      scan = create(:complete_scan)
      target.scans << scan

      expect(target.scans).to include(scan)
      expect(scan.reload.targets).to include(target)
    end

    it "can access scan properties through association" do
      scan = create(:complete_scan, name: "Test Scan")
      target.scans << scan

      expect(target.scans.first.name).to eq("Test Scan")
    end
  end

  describe "scheduled scans filtering" do
    context "with mixed scheduled and unscheduled scans" do
      let!(:scheduled_scan) do
        scan = build(:scan, name: "Scheduled Scan")
        scan.targets << target
        scan.probes << probe
        scan.recurrence = IceCube::Rule.daily.hour_of_day(9).minute_of_hour(0)
        scan.save!
        scan
      end

      let!(:unscheduled_scan) do
        scan = build(:scan, name: "Unscheduled Scan")
        scan.targets << target
        scan.probes << probe
        scan.save!
        scan
      end

      it "filters to only scheduled scans" do
        scheduled_scans = target.scans.scheduled

        expect(scheduled_scans).to include(scheduled_scan)
        expect(scheduled_scans).not_to include(unscheduled_scan)
        expect(scheduled_scans.count).to eq(1)
      end

      it "includes all scans in the general association" do
        all_scans = target.scans

        expect(all_scans).to include(scheduled_scan, unscheduled_scan)
        expect(all_scans.count).to eq(2)
      end
    end

    context "with only scheduled scans" do
      let!(:daily_scan) do
        scan = build(:scan, name: "Daily Scan")
        scan.targets << target
        scan.probes << probe
        scan.recurrence = IceCube::Rule.daily.hour_of_day(9).minute_of_hour(0)
        scan.save!
        scan
      end

      let!(:weekly_scan) do
        scan = build(:scan, name: "Weekly Scan")
        scan.targets << target
        scan.probes << probe
        scan.recurrence = IceCube::Rule.weekly.day(:monday).hour_of_day(14).minute_of_hour(30)
        scan.save!
        scan
      end

      it "returns all scans when filtering for scheduled" do
        scheduled_scans = target.scans.scheduled

        expect(scheduled_scans).to include(daily_scan, weekly_scan)
        expect(scheduled_scans.count).to eq(2)
      end
    end

    context "with only unscheduled scans" do
      let!(:one_time_scan) do
        scan = build(:scan, name: "One-time Scan")
        scan.targets << target
        scan.probes << probe
        scan.save!
        scan
      end

      it "returns empty collection when filtering for scheduled" do
        scheduled_scans = target.scans.scheduled

        expect(scheduled_scans).to be_empty
        expect(scheduled_scans.count).to eq(0)
      end
    end

    context "with no scans" do
      it "returns empty collection when filtering for scheduled" do
        scheduled_scans = target.scans.scheduled

        expect(scheduled_scans).to be_empty
        expect(scheduled_scans.count).to eq(0)
      end
    end
  end

  describe "schedule information access" do
    let!(:scheduled_scan) do
      scan = build(:scan, name: "Daily Test")
      scan.targets << target
      scan.probes << probe
      scan.recurrence = IceCube::Rule.daily.hour_of_day(15).minute_of_hour(30)
      scan.save!
      scan
    end

    it "provides access to schedule information through association" do
      scheduled_scans = target.scans.scheduled
      scan = scheduled_scans.first

      expect(scan.recurrence).to be_present
      expect(scan.scheduled?).to be true
    end

    it "allows checking for recurrence patterns" do
      scheduled_scans = target.scans.scheduled
      scan = scheduled_scans.first

      # The scan should have a daily recurrence
      expect(scan.recurrence).to be_a(IceCube::DailyRule)
    end
  end
end
