require 'rails_helper'

RSpec.describe Stats::ScanAndTargetCountsOverTime do
  describe '#call' do
    let(:days) { 7 }
    let(:subject) { described_class.new(days: days) }
    let(:scan_data) do
      {
        dates: [ "01 Jun", "02 Jun", "03 Jun" ],
        counts: [ 3, 5, 7 ]
      }
    end
    let(:target_data) do
      {
        dates: [ "01 Jun", "02 Jun", "04 Jun" ],
        counts: [ 10, 15, 25 ]
      }
    end

    before do
      allow(Stats::TotalScansData).to receive(:call).with(days: days).and_return(scan_data)
      allow(Stats::TargetsTimelineData).to receive(:call).with(days: days).and_return(target_data)
    end

    it "combines scan and target data correctly" do
      result = subject.call

      expect(result).to eq([
        { date: "01 Jun", scan_count: 3, target_count: 10 },
        { date: "02 Jun", scan_count: 5, target_count: 15 },
        { date: "03 Jun", scan_count: 7, target_count: 0 },
        { date: "04 Jun", scan_count: 0, target_count: 25 }
      ])
    end

    context "when a service returns nil data" do
      let(:scan_data) { { dates: nil, counts: nil } }

      it "handles nil data gracefully" do
        result = subject.call

        expect(result).to eq([
          { date: "01 Jun", scan_count: 0, target_count: 10 },
          { date: "02 Jun", scan_count: 0, target_count: 15 },
          { date: "04 Jun", scan_count: 0, target_count: 25 }
        ])
      end
    end

    context "when both services return empty data" do
      let(:scan_data) { { dates: [], counts: [] } }
      let(:target_data) { { dates: [], counts: [] } }

      it "returns an empty array" do
        result = subject.call

        expect(result).to eq([])
      end
    end

    context "with custom number of days" do
      let(:days) { 14 }

      it "passes the correct number of days to the dependencies" do
        subject.call

        expect(Stats::TotalScansData).to have_received(:call).with(days: 14)
        expect(Stats::TargetsTimelineData).to have_received(:call).with(days: 14)
      end
    end
  end
end
