require 'rails_helper'

RSpec.describe Stats::ProbesPassedFailedTimelineData do
  describe '#call' do
    let!(:target) { create(:target) }
    let!(:detector) { create(:detector, name: 'TestDetector') }
    let!(:probe) { create(:probe, detector: detector) }
    let!(:scan) { create(:complete_scan) }
    let(:service) { described_class.new }
    let(:target_specific_service) { described_class.new(target_id: target.id) }

    context 'when no probe results exist' do
      it 'returns empty data arrays' do
        result = service.call

        # Should have no data since there are no probe results
        expect(result[:dates]).to be_empty
        expect(result[:asr_percentages]).to be_empty
        expect(result[:passed_counts]).to be_empty
      end
    end

    context 'when probe results exist' do
      before do
        # Use targets from complete_scan factory instead of creating new ones
        target_from_scan = scan.targets.first

        # Create reports on different days using scan targets
        @report1 = create(:report, target: target_from_scan, scan: scan, created_at: Time.zone.today)
        @report2 = create(:report, target: target_from_scan, scan: scan, created_at: 1.day.ago)
        @report3 = create(:report, target: target_from_scan, scan: scan, created_at: 15.days.ago)

        # Use second target from complete_scan factory
        @other_target = scan.targets.second
        @other_report = create(:report, target: @other_target, scan: scan, created_at: Time.zone.today)

        # Create probe results for the reports
        probe_from_scan = scan.probes.first
        create(:probe_result, report: @report1, probe: probe_from_scan, detector: detector, passed: 10, total: 15, created_at: Time.zone.today)
        create(:probe_result, report: @report2, probe: probe_from_scan, detector: detector, passed: 5, total: 10, created_at: 1.day.ago)
        create(:probe_result, report: @report3, probe: probe_from_scan, detector: detector, passed: 8, total: 12, created_at: 15.days.ago)
        create(:probe_result, report: @other_report, probe: probe_from_scan, detector: detector, passed: 20, total: 25, created_at: Time.zone.today)
      end

      it 'returns correct daily ASR percentages for all targets' do
        result = service.call

        # We should have 3 days of data (only days with probe results)
        expect(result[:dates].length).to eq(3)
        expect(result[:asr_percentages].length).to eq(3)
        expect(result[:passed_counts].length).to eq(3)

        # Find indices by matching dates
        today_date = Time.zone.today.strftime("%d %b")
        yesterday_date = 1.day.ago.strftime("%d %b")
        fifteen_days_ago_date = 15.days.ago.strftime("%d %b")

        today_index = result[:dates].index(today_date)
        yesterday_index = result[:dates].index(yesterday_date)
        fifteen_days_ago_index = result[:dates].index(fifteen_days_ago_date)

        # Verify today's data (should include both targets)
        # Total: (15 + 25) = 40, Passed: (10 + 20) = 30, ASR: 30/40 * 100 = 75.0%
        expect(result[:asr_percentages][today_index]).to eq(75.0)
        expect(result[:passed_counts][today_index]).to eq(30)

        # Verify 1 day ago data
        # Total: 10, Passed: 5, ASR: 5/10 * 100 = 50.0%
        expect(result[:asr_percentages][yesterday_index]).to eq(50.0)
        expect(result[:passed_counts][yesterday_index]).to eq(5)

        # Verify 15 days ago data
        # Total: 12, Passed: 8, ASR: 8/12 * 100 = 66.7%
        expect(result[:asr_percentages][fifteen_days_ago_index]).to eq(66.7)
        expect(result[:passed_counts][fifteen_days_ago_index]).to eq(8)
      end

      it 'returns data for specific target only when target_id is provided' do
        target_from_scan = scan.targets.first
        target_specific_service = described_class.new(target_id: target_from_scan.id)
        result = target_specific_service.call

        # We should have 3 days of data (only days with probe results for this target)
        expect(result[:dates].length).to eq(3)

        # Find today's data by matching the date
        today_date = Time.zone.today.strftime("%d %b")
        today_index = result[:dates].index(today_date)

        # Verify today's data (should only include the target's data)
        # Total: 15, Passed: 10, ASR: 10/15 * 100 = 66.7%
        expect(result[:asr_percentages][today_index]).to eq(66.7)
        expect(result[:passed_counts][today_index]).to eq(10)

        # Verify that other target's data is not included
        other_service = described_class.new(target_id: @other_target.id)
        other_result = other_service.call

        # Other target should only have 1 day of data (today only)
        expect(other_result[:dates].length).to eq(1)
        expect(other_result[:dates].first).to eq(today_date)
        # Total: 25, Passed: 20, ASR: 20/25 * 100 = 80.0%
        expect(other_result[:asr_percentages].first).to eq(80.0)
        expect(other_result[:passed_counts].first).to eq(20)
      end

      it 'formats dates correctly' do
        result = service.call

        # Dates should be in format "DD MMM"
        date_format = /^\d{2} [A-Za-z]{3}$/
        expect(result[:dates].all? { |date| date =~ date_format }).to be true

        # Should include today's date since we have data for today
        today_date = Time.zone.today.strftime("%d %b")
        expect(result[:dates]).to include(today_date)
      end
    end

    context 'with multiple probe results per report' do
      before do
        target_from_scan = scan.targets.first
        report = create(:report, target: target_from_scan, scan: scan, created_at: Time.zone.today)
        probe2 = create(:probe, detector: detector)

        # Create multiple probe results for the same report
        create(:probe_result, report: report, probe: scan.probes.first, detector: detector, passed: 7, total: 12, created_at: Time.zone.today)
        create(:probe_result, report: report, probe: probe2, detector: detector, passed: 3, total: 8, created_at: Time.zone.today)
      end

      it 'aggregates all probe results for the day' do
        result = service.call

        # Should have 1 day of data (today only, since that's when probe results exist)
        expect(result[:dates].length).to eq(1)
        expect(result[:dates].first).to eq(Time.zone.today.strftime("%d %b"))

        # Total: 12 + 8 = 20, Passed: 7 + 3 = 10, ASR: 10/20 * 100 = 50.0%
        expect(result[:asr_percentages].first).to eq(50.0)
        expect(result[:passed_counts].first).to eq(10)
      end
    end
  end
end
