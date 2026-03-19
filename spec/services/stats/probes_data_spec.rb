require 'rails_helper'

RSpec.describe Stats::ProbesData do
  describe '#call' do
    subject { described_class.new(days: days).call }
    let(:days) { 30 }

    context 'when no probes exist' do
      it 'returns zero counts' do
        result = subject

        expect(result[:total]).to eq(0)
        expect(result[:counts].all?(&:zero?)).to be true
        expect(result[:percentage_new_last_30_days]).to eq(0)
      end
    end

    context 'when probes exist outside the 30-day range' do
      before do
        # Create probes older than 30 days
        create_list(:probe, 5, release_date: 2.months.ago)
      end

      it 'counts total probes but shows zero new probes' do
        result = subject

        expect(result[:total]).to eq(5)
        expect(result[:counts].all?(&:zero?)).to be true
        expect(result[:percentage_new_last_30_days]).to eq(0)
      end
    end

    context 'when probes exist within the 30-day range' do
      before do
        # Create probes from different days within the last 30 days
        create(:probe, release_date: Time.zone.today)
        create(:probe, release_date: Time.zone.today)
        create(:probe, release_date: 5.days.ago)
        create(:probe, release_date: 15.days.ago)
        create(:probe, release_date: 25.days.ago)

        # Create a probe just outside the 30-day range for the daily chart
        # but within range for the percentage calculation
        create(:probe, release_date: 30.days.ago)

        # Create an older probe
        create(:probe, release_date: 2.months.ago)
      end

      it 'counts probes correctly' do
        result = subject

        # 7 probes total
        expect(result[:total]).to eq(7)

        # 6 probes in the last 30 days (including the one from exactly 30 days ago)
        expect(result[:percentage_new_last_30_days]).to eq(85.7) # 6/7 * 100

        # Daily counts should match what we created
        expect(result[:counts].count(&:positive?)).to eq(4) # 4 days with new probes

        # Check today's count
        today_index = 29 # Last day in the 30-day range
        expect(result[:counts][today_index]).to eq(2) # 2 probes today

        # Check 5 days ago count
        days_ago_5_index = 24 # 29 - 5
        expect(result[:counts][days_ago_5_index]).to eq(1) # 1 probe 5 days ago

        # Check 15 days ago count
        days_ago_15_index = 14 # 29 - 15
        expect(result[:counts][days_ago_15_index]).to eq(1) # 1 probe 15 days ago

        # Check 25 days ago count
        days_ago_25_index = 4 # 29 - 25
        expect(result[:counts][days_ago_25_index]).to eq(1) # 1 probe 25 days ago

        # 30 days ago should not be included in daily counts
        days_ago_30_index = 0 # First day in the range would be 29 days ago
        expect(result[:counts][days_ago_30_index]).to eq(0)
      end
    end

    context 'when all probes are within the 30-day range' do
      before do
        create_list(:probe, 3, release_date: 10.days.ago)
      end

      it 'shows 100% new probes' do
        result = subject

        expect(result[:total]).to eq(3)
        expect(result[:percentage_new_last_30_days]).to eq(100)

        # Check 10 days ago count
        days_ago_10_index = 19 # 29 - 10
        expect(result[:counts][days_ago_10_index]).to eq(3)
      end
    end

    context 'with release dates on range boundaries' do
      before do
        # Create probe on the start date (29 days ago)
        create(:probe, release_date: 29.days.ago.to_date)

        # Create probe on end date (today)
        create(:probe, release_date: Time.zone.today)
      end

      it 'includes both start and end date in the range' do
        result = subject

        # Check first day in range (29 days ago)
        expect(result[:counts].first).to eq(1)

        # Check last day in range (today)
        expect(result[:counts].last).to eq(1)

        # Total 30 days of data
        expect(result[:counts].length).to eq(30)
      end
    end

    context 'with custom days parameter' do
      let(:days) { 7 }

      before do
        # Create probes within 7 days
        create(:probe, release_date: Time.zone.today)
        create(:probe, release_date: 3.days.ago)
        create(:probe, release_date: 6.days.ago)

        # Create probe outside 7-day range
        create(:probe, release_date: 10.days.ago)
      end

      it 'returns data for the specified number of days' do
        result = subject

        # Total probes count should include all
        expect(result[:total]).to eq(4)

        # Daily counts should be for 7 days
        expect(result[:counts].length).to eq(7)

        # Check counts
        expect(result[:counts].last).to eq(1) # today
        expect(result[:counts][3]).to eq(1)   # 3 days ago (6 - 3)
        expect(result[:counts][0]).to eq(1)   # 6 days ago

        # Percentage should be for 7-day period
        expect(result[:percentage_new_last_30_days]).to eq(75.0) # 3/4 * 100
      end
    end
  end
end
