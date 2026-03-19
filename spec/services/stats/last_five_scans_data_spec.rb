require 'rails_helper'

RSpec.describe Stats::LastFiveScansData, type: :service do
  describe '#call' do
    let(:target1) { create(:target, name: 'Model 1') }
    let(:target2) { create(:target, name: 'Model 2') }
    let(:target3) { create(:target, name: 'Model 3') }
    let(:scan) { create(:complete_scan) }

    before do
      # Stub service calls that might be triggered
      allow_any_instance_of(RunGarakScan).to receive(:call)
      allow_any_instance_of(ToastNotifier).to receive(:call)
    end

    context 'when there are completed reports' do
      before do
        # Create 7 completed reports (2 more than we need to test limiting)
        report1 = create(:report, :completed, target: target1, scan: scan, created_at: 7.days.ago)
        report2 = create(:report, :completed, target: target2, scan: scan, created_at: 6.days.ago)
        report3 = create(:report, :completed, target: target3, scan: scan, created_at: 5.days.ago)
        report4 = create(:report, :completed, target: target1, scan: scan, created_at: 4.days.ago)
        report5 = create(:report, :completed, target: target2, scan: scan, created_at: 3.days.ago)
        report6 = create(:report, :completed, target: target3, scan: scan, created_at: 2.days.ago)
        report7 = create(:report, :completed, target: target1, scan: scan, created_at: 1.day.ago)

        # Create probe results for each report with different scores
        create(:probe_result, report: report1, passed: 8, total: 10) # 80%
        create(:probe_result, report: report2, passed: 6, total: 10) # 60%
        create(:probe_result, report: report3, passed: 9, total: 10) # 90%
        create(:probe_result, report: report4, passed: 5, total: 10) # 50%
        create(:probe_result, report: report5, passed: 7, total: 10) # 70%
        create(:probe_result, report: report6, passed: 4, total: 10) # 40%
        create(:probe_result, report: report7, passed: 10, total: 10) # 100%
      end

      it 'returns data for the last 5 completed reports' do
        result = described_class.new.call

        # Should have 5 entries
        expect(result[:models].length).to eq(5)
        expect(result[:values].length).to eq(5)

        # Check that the models and values match up in reverse chronological order
        # The most recent 5 reports should be included (reports 3-7)
        expect(result[:models]).to eq([ 'Model 1', 'Model 3', 'Model 2', 'Model 1', 'Model 3' ])
        expect(result[:values]).to eq([ 100, 40, 70, 50, 90 ])
      end
    end

    context 'when there are fewer than 5 completed reports' do
      before do
        report1 = create(:report, :completed, target: target1, scan: scan, created_at: 3.days.ago)
        report2 = create(:report, :completed, target: target2, scan: scan, created_at: 2.days.ago)
        report3 = create(:report, :completed, target: target3, scan: scan, created_at: 1.day.ago)

        create(:probe_result, report: report1, passed: 8, total: 10) # 80%
        create(:probe_result, report: report2, passed: 6, total: 10) # 60%
        create(:probe_result, report: report3, passed: 9, total: 10) # 90%

        # Create a non-completed report that should be excluded
        incomplete_report = create(:report, :running, target: target1, scan: scan, created_at: 4.days.ago)
        create(:probe_result, report: incomplete_report, passed: 3, total: 10) # 30%
      end

      it 'returns data for all available completed reports' do
        result = described_class.new.call

        expect(result[:models].length).to eq(3)
        expect(result[:values].length).to eq(3)

        expect(result[:models]).to eq([ 'Model 3', 'Model 2', 'Model 1' ])
        expect(result[:values]).to eq([ 90, 60, 80 ])
      end
    end

    context 'when there are no completed reports' do
      before do
        create(:report, :running, target: target1, scan: scan)
        create(:report, :processing, target: target2, scan: scan)
      end

      it 'returns empty arrays' do
        result = described_class.new.call

        expect(result[:models]).to eq([])
        expect(result[:values]).to eq([])
      end
    end

    context 'when reports have zero tests' do
      before do
        report = create(:report, :completed, target: target1, scan: scan)
        create(:probe_result, report: report, passed: 0, total: 0)
      end

      it 'handles zero division correctly' do
        result = described_class.new.call

        expect(result[:models]).to eq([ 'Model 1' ])
        expect(result[:values]).to eq([ 0 ]) # Score should be 0 when total is 0
      end
    end
  end
end
