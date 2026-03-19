require 'rails_helper'

RSpec.describe Stats::AvgScanTimeData, type: :service do
  describe '#initialize' do
    it 'sets default days to 7' do
      service = described_class.new
      expect(service.instance_variable_get(:@days)).to eq(7)
    end

    it 'allows custom days to be set' do
      service = described_class.new(days: 30)
      expect(service.instance_variable_get(:@days)).to eq(30)
    end

    it 'handles invalid days parameter' do
      service = described_class.new(days: 0)
      expect(service.instance_variable_get(:@days)).to eq(7)

      service = described_class.new(days: -5)
      expect(service.instance_variable_get(:@days)).to eq(7)

      service = described_class.new(days: 'abc')
      expect(service.instance_variable_get(:@days)).to eq(7)
    end
  end

  describe '#call' do
    let(:current_time) { Time.zone.local(2023, 6, 1, 12, 0, 0) }

    before do
      allow(Time).to receive(:current).and_return(current_time)
      allow_any_instance_of(RunGarakScan).to receive(:call)
      allow_any_instance_of(ToastNotifier).to receive(:call)
    end

    context 'with data in current period only' do
      before do
        target = create(:target)
        scan = create(:complete_scan)

        3.times do |i|
          report = create(:report, :completed,
                         target: target,
                         scan: scan,
                         created_at: 2.days.ago,
                         start_time: 2.days.ago + i.hours,
                         end_time: 2.days.ago + (i + 1).hours)
        end
      end

      it 'calculates average time correctly' do
        service = described_class.new
        result = service.call

        expect(result[:avg_seconds]).to be_within(1).of(3600)
        expect(result[:formatted_time]).to match(/^(?:1h|59m \d+s)$/)
        expect(result[:period_days]).to eq(7)
      end
    end

    context 'with data in both periods' do
      before do
        target = create(:target)
        scan = create(:complete_scan)

        3.times do |i|
          create(:report, :completed,
                 target: target,
                 scan: scan,
                 created_at: 2.days.ago,
                 start_time: 2.days.ago + i.hours,
                 end_time: 2.days.ago + (i + 1).hours)
        end

        3.times do |i|
          create(:report, :completed,
                 target: target,
                 scan: scan,
                 created_at: 10.days.ago,
                 start_time: 10.days.ago + i.hours,
                 end_time: 10.days.ago + i.hours + 30.minutes)
        end
      end

      it 'calculates percentage change correctly' do
        service = described_class.new
        result = service.call

        expect(result[:formatted_time]).to match(/^(?:1h|59m \d+s)$/)

        expect(result[:percentage_change]).to be_within(1).of(100.0)
      end
    end

    context 'with no data' do
      it 'handles empty dataset' do
        service = described_class.new
        result = service.call

        expect(result[:avg_seconds]).to eq(0)
        expect(result[:formatted_time]).to eq('0s')
        expect(result[:percentage_change]).to be_nil
      end
    end

    context 'with different time formats' do
      it 'formats durations correctly' do
        service = described_class.new

        format_duration = service.send(:format_duration, 0)
        expect(format_duration).to eq('0s')

        format_duration = service.send(:format_duration, 30)
        expect(format_duration).to eq('30s')

        format_duration = service.send(:format_duration, 90)
        expect(format_duration).to eq('1m 30s')

        format_duration = service.send(:format_duration, 3600)
        expect(format_duration).to eq('1h')

        format_duration = service.send(:format_duration, 3630)
        expect(format_duration).to eq('1h')

        format_duration = service.send(:format_duration, 3660)
        expect(format_duration).to eq('1h 1m')

        format_duration = service.send(:format_duration, 3690)
        expect(format_duration).to eq('1h 1m')

        format_duration = service.send(:format_duration, 7200)
        expect(format_duration).to eq('2h')
      end
    end

    context 'trend data calculation' do
      before do
        target = create(:target)
        scan = create(:complete_scan)

        [ 1, 3, 5, 7, 9 ].each do |days_ago|
          create(:report, :completed,
                 target: target,
                 scan: scan,
                 created_at: days_ago.days.ago,
                 start_time: days_ago.days.ago,
                 end_time: days_ago.days.ago + days_ago.hours)
        end
      end

      it 'includes trend data in the result' do
        service = described_class.new
        result = service.call

        expect(result[:trend_data]).to be_an(Array)
        expect(result[:trend_data].length).to eq(7)
      end
    end
  end
end
