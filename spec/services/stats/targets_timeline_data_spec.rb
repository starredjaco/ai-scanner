require 'rails_helper'

RSpec.describe Stats::TargetsTimelineData, type: :service do
  describe '#initialize' do
    it 'sets default days to 30' do
      service = described_class.new
      expect(service.instance_variable_get(:@days)).to eq(30)
    end

    it 'allows custom days to be set' do
      service = described_class.new(days: 15)
      expect(service.instance_variable_get(:@days)).to eq(15)
    end
  end

  describe '#call' do
    let(:today) { Time.zone.local(2023, 6, 1).to_date } # Using a fixed date for testing

    before do
      allow(Time.zone).to receive(:today).and_return(today)
    end

    context 'when there are targets across the timeline' do
      before do
        # Create targets spread throughout the timeline
        create(:target, created_at: today - 35.days) # Before timeline
        create(:target, created_at: today - 29.days) # Day 1
        create(:target, created_at: today - 29.days) # Day 1
        create(:target, created_at: today - 20.days) # Day 10
        create(:target, created_at: today - 10.days) # Day 20
        create(:target, created_at: today - 5.days)  # Day 25
        create(:target, created_at: today - 5.days)  # Day 25
        create(:target, created_at: today)           # Day 30
      end

      it 'returns the cumulative count of targets per day' do
        service = described_class.new
        result = service.call

        expect(result[:dates].length).to eq(30)
        expect(result[:counts].length).to eq(30)

        # First day should have 2 targets plus 1 from before timeline = 3
        expect(result[:counts][0]).to eq(3)

        # Day 10 should have 1 more target = 4
        expect(result[:counts][9]).to eq(4)

        # Day 20 should have 1 more target = 5
        expect(result[:counts][19]).to eq(5)

        # Day 25 should have 2 more targets = 7
        expect(result[:counts][24]).to eq(7)

        # Day 30 (today) should have 1 more target = 8
        expect(result[:counts][29]).to eq(8)
      end

      it 'respects custom days parameter' do
        # We need to verify the exact behavior without making assumptions
        service = described_class.new(days: 10)
        result = service.call

        expect(result[:dates].length).to eq(10)
        expect(result[:counts].length).to eq(10)

        # Just verify it's counting correctly - final day should have all targets
        expect(result[:counts].last).to eq(Target.count)
      end
    end

    context 'when there are no targets' do
      before do
        Target.destroy_all
      end

      it 'returns zeros for all days' do
        service = described_class.new
        result = service.call

        expect(result[:dates].length).to eq(30)
        expect(result[:counts].length).to eq(30)
        expect(result[:counts].all?(0)).to be true
      end
    end

    context 'when all targets are before the timeline' do
      before do
        create(:target, created_at: today - 31.days)
        create(:target, created_at: today - 45.days)
      end

      it 'starts with the pre-existing count and does not change' do
        service = described_class.new
        result = service.call

        expect(result[:counts].all?(2)).to be true
      end
    end
  end
end
