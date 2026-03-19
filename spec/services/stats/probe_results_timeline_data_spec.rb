require 'rails_helper'

RSpec.describe Stats::ProbeResultsTimelineData, type: :service do
  describe '#call' do
    let!(:target) { create(:target) }
    let!(:scan) { create(:complete_scan) }
    let!(:probe) { scan.probes.first }  # Use a probe from the scan
    let!(:report) { create(:report, target: target, scan: scan) }
    let(:service) { described_class.new(probe_id: probe.id) }

    context 'when no probe results exist' do
      it 'returns zeroed data for each day' do
        result = service.call

        expect(result[:dates].length).to eq(30)
        expect(result[:passed_counts].length).to eq(30)
        expect(result[:failed_counts].length).to eq(30)
        expect(result[:total_counts].length).to eq(30)

        expect(result[:passed_counts].all?(&:zero?)).to be true
        expect(result[:failed_counts].all?(&:zero?)).to be true
        expect(result[:total_counts].all?(&:zero?)).to be true
      end
    end

    context 'when probe results exist' do
      before do
        detector = create(:detector)

        report1 = create(:report, target: target, scan: scan, created_at: Time.zone.today)
        report2 = create(:report, target: target, scan: scan, created_at: Time.zone.today - 1.hour)
        report3 = create(:report, target: target, scan: scan, created_at: 1.day.ago)
        report4 = create(:report, target: target, scan: scan, created_at: 15.days.ago)

        create(:probe_result, report: report1, probe: probe, detector: detector, passed: 5, total: 10, created_at: Time.zone.today)
        create(:probe_result, report: report2, probe: probe, detector: detector, passed: 3, total: 7, created_at: Time.zone.today) # same day
        create(:probe_result, report: report3, probe: probe, detector: detector, passed: 8, total: 10, created_at: 1.day.ago)
        create(:probe_result, report: report4, probe: probe, detector: detector, passed: 2, total: 5, created_at: 15.days.ago)

        other_probe = scan.probes.last
        other_report = create(:report, target: target, scan: scan, created_at: Time.zone.today - 2.hours)
        create(:probe_result, report: other_report, probe: other_probe, detector: detector, passed: 10, total: 10, created_at: Time.zone.today)
      end

      it 'returns correct daily counts' do
        result = service.call

        expect(result[:dates].length).to eq(30)
        expect(result[:passed_counts].length).to eq(30)
        expect(result[:failed_counts].length).to eq(30)
        expect(result[:total_counts].length).to eq(30)

        expect(result[:passed_counts].sum).to be > 0
        expect(result[:failed_counts].sum).to be > 0
        expect(result[:total_counts].sum).to be > 0

        expect(result[:passed_counts].sum + result[:failed_counts].sum).to eq(result[:total_counts].sum)

        expect(result[:passed_counts].count(&:zero?)).to be > 20
      end

      it 'formats dates correctly' do
        result = service.call

        date_format = /^\d{2} [A-Za-z]{3}$/
        expect(result[:dates].all? { |date| date =~ date_format }).to be true

        expect(result[:dates].last).to eq(Time.zone.today.strftime("%d %b"))
      end

      it 'ignores probe results for other probes' do
        result = service.call

        expect(result[:total_counts].sum).to eq(32)  # 10 + 7 + 10 + 5

        other_probe_service = described_class.new(probe_id: scan.probes.last.id)
        other_result = other_probe_service.call
        expect(other_result[:total_counts].last).to eq(10)
      end
    end

    context 'with an invalid probe id' do
      it 'raises an appropriate error' do
        expect { described_class.new(probe_id: -1).call }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
