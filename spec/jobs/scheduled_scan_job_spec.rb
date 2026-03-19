# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScheduledScanJob, type: :job do
  let(:target) { create(:target, status: "good") }

  before do
    allow_any_instance_of(ToastNotifier).to receive(:call)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  # Helper to create a complete scan with targets, probes, and schedule
  # Uses update_column to bypass the before_validation callback that would override next_scheduled_run
  def create_scheduled_scan(target_count: 1, next_run: 1.minute.ago, recurrence: IceCube::Rule.hourly)
    scan = create(:complete_scan, recurrence: recurrence)
    # Bypass validation callbacks that recalculate next_scheduled_run
    scan.update_column(:next_scheduled_run, next_run)
    # complete_scan already creates 2 targets, add more if needed
    (target_count - 2).times { scan.targets << create(:target, status: "good") } if target_count > 2
    # Delete any reports auto-created by the after_create callback
    scan.reports.delete_all
    scan.reload
  end

  describe "#perform" do
    describe "processing scheduled scans" do
      it "creates reports for due scans" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)

        # complete_scan already creates 2 targets
        expect {
          described_class.new.perform
        }.to change(Report, :count).by(2)
      end

      it "updates next_scheduled_run after processing" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)
        original_next_run = scan.next_scheduled_run

        described_class.new.perform

        scan.reload
        expect(scan.next_scheduled_run).to be > original_next_run
        expect(scan.next_scheduled_run).to be > Time.now.utc
      end

      it "handles one-time scans (sets next_scheduled_run to nil)" do
        scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: nil)

        # complete_scan creates 2 targets
        expect {
          described_class.new.perform
        }.to change(Report, :count).by(2)

        scan.reload
        expect(scan.next_scheduled_run).to be_nil
      end

      it "does not process scans not yet due" do
        scan = create_scheduled_scan(next_run: 1.hour.from_now)

        expect {
          described_class.new.perform
        }.not_to change(Report, :count)
      end

      it "processes multiple due scans independently" do
        scan1 = create_scheduled_scan(next_run: 2.minutes.ago, recurrence: IceCube::Rule.hourly)
        scan2 = create_scheduled_scan(next_run: 1.minute.ago, recurrence: IceCube::Rule.daily)

        # Each scan has 2 targets (from complete_scan factory), so 4 reports total
        expect {
          described_class.new.perform
        }.to change(Report, :count).by(4)

        expect(scan1.reload.next_scheduled_run).to be > Time.now.utc
        expect(scan2.reload.next_scheduled_run).to be > Time.now.utc
      end
    end

    describe "atomic claiming (multi-pod safety)" do
      it "skips scans already claimed by another process" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)

        # Simulate another process claiming the scan first
        allow(Scan).to receive(:where).and_call_original
        allow(Scan).to receive(:where).with(id: scan.id).and_return(
          double(where: double(update_all: 0)) # Simulate failed claim (0 rows updated)
        )

        expect {
          described_class.new.perform
        }.not_to change(Report, :count)
      end

      it "uses atomic UPDATE...WHERE pattern for claiming" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)

        # Verify the atomic update is called with correct conditions
        expect(Scan).to receive(:where).with(id: scan.id).and_call_original

        described_class.new.perform
      end

      it "reloads scan after successful claim before calling rerun" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)

        # The scan should be reloaded after atomic update to get fresh state
        expect_any_instance_of(Scan).to receive(:reload).and_call_original

        described_class.new.perform
      end
    end

    describe "next_scheduled_run calculation" do
      it "calculates next run using IceCube schedule" do
        scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: IceCube::Rule.hourly)

        described_class.new.perform

        scan.reload
        # Next run should be approximately 1 hour from now (within a few minutes tolerance)
        expect(scan.next_scheduled_run).to be_within(5.minutes).of(1.hour.from_now)
      end

      it "rounds next_scheduled_run to beginning of minute" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)

        described_class.new.perform

        scan.reload
        expect(scan.next_scheduled_run.sec).to eq(0)
      end

      it "handles daily recurrence" do
        scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: IceCube::Rule.daily)

        described_class.new.perform

        scan.reload
        expect(scan.next_scheduled_run).to be_within(5.minutes).of(1.day.from_now)
      end

      it "handles weekly recurrence" do
        scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: IceCube::Rule.weekly)

        described_class.new.perform

        scan.reload
        expect(scan.next_scheduled_run).to be_within(5.minutes).of(1.week.from_now)
      end

      it "handles monthly recurrence" do
        scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: IceCube::Rule.monthly)

        described_class.new.perform

        scan.reload
        expect(scan.next_scheduled_run).to be_within(5.minutes).of(1.month.from_now)
      end

      it "schedules next run on the correct day of month" do
        target_day = 15
        scan = create_scheduled_scan(
          next_run: 1.minute.ago,
          recurrence: IceCube::Rule.monthly.day_of_month(target_day).hour_of_day(12).minute_of_hour(0)
        )

        described_class.new.perform

        scan.reload
        expect(scan.next_scheduled_run.day).to eq(target_day)
        expect(scan.next_scheduled_run).to be > Time.now.utc
      end
    end

    describe "logging" do
      it "logs when a scan is successfully claimed" do
        scan = create_scheduled_scan(next_run: 1.minute.ago)

        # Allow other log calls (e.g., from StartPendingScansJob triggered by create_reports)
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\[ScheduledScan\] Claimed scan #{scan.id}/)

        described_class.new.perform
      end
    end
  end

  describe "#claim_scan_atomically" do
    let(:job) { described_class.new }
    let(:scan) { create_scheduled_scan(next_run: 1.minute.ago) }

    it "returns true when claim succeeds" do
      next_run = 1.hour.from_now.beginning_of_minute
      result = job.send(:claim_scan_atomically, scan, next_run)

      expect(result).to be true
    end

    it "returns false when scan already claimed" do
      next_run = 1.hour.from_now.beginning_of_minute

      # First claim succeeds
      job.send(:claim_scan_atomically, scan, next_run)

      # Second claim fails (next_scheduled_run is now in the future)
      result = job.send(:claim_scan_atomically, scan, next_run)

      expect(result).to be false
    end

    it "updates next_scheduled_run atomically" do
      next_run = 1.hour.from_now.beginning_of_minute

      job.send(:claim_scan_atomically, scan, next_run)

      scan.reload
      expect(scan.next_scheduled_run).to be_within(1.second).of(next_run)
    end

    it "updates updated_at timestamp" do
      next_run = 1.hour.from_now.beginning_of_minute
      original_updated_at = scan.updated_at

      travel_to(1.second.from_now) do
        job.send(:claim_scan_atomically, scan, next_run)
      end

      scan.reload
      expect(scan.updated_at).to be > original_updated_at
    end
  end

  describe "#calculate_next_run_for" do
    let(:job) { described_class.new }

    it "returns nil for scans without recurrence" do
      scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: nil)

      result = job.send(:calculate_next_run_for, scan)

      expect(result).to be_nil
    end

    it "returns next occurrence for scans with recurrence" do
      scan = create_scheduled_scan(next_run: 1.minute.ago, recurrence: IceCube::Rule.hourly)

      result = job.send(:calculate_next_run_for, scan)

      expect(result).to be_within(5.minutes).of(1.hour.from_now)
      expect(result.sec).to eq(0) # beginning_of_minute
    end
  end

  describe "queue configuration" do
    it "uses default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
