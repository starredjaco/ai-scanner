require 'rails_helper'

RSpec.describe Stats::ReportsTimelineData, type: :service do
  describe '#call' do
    let!(:target) { create(:target) }
    let!(:scan) { create(:complete_scan) }

    context 'when no reports exist' do
      it 'returns data for each day' do
        result = described_class.new.call

        # Should have 30 days of data (today + 29 previous days)
        expect(result[:dates].length).to eq(30)
        expect(result[:counts].length).to eq(30)

        # The counts should be non-negative
        expect(result[:counts].all? { |count| count >= 0 }).to be true
      end
    end

    context 'when reports exist' do
      before do
        # Create reports on different days
        create(:report, target: target, scan: scan, created_at: Time.zone.today)
        create(:report, target: target, scan: scan, created_at: 1.day.ago)
        create(:report, target: target, scan: scan, created_at: 2.days.ago)
        create(:report, target: target, scan: scan, created_at: 15.days.ago)

        # Reports outside the 30-day window
        create(:report, target: target, scan: scan, created_at: 35.days.ago)
        create(:report, target: target, scan: scan, created_at: 36.days.ago)
      end

      it 'returns correct cumulative counts for all reports' do
        result = described_class.new.call

        # We should have 30 days of data
        expect(result[:dates].length).to eq(30)
        expect(result[:counts].length).to eq(30)

        # Final count should include all reports (including those outside the window)
        expect(result[:counts].last).to be >= 4

        # First value should start with at least the reports outside the window
        expect(result[:counts].first).to be >= 2

        # Last count should be greater than first (indicating cumulative behavior)
        expect(result[:counts].last).to be > result[:counts].first

        # Counts should be non-decreasing
        expect(result[:counts]).to eq(result[:counts].sort)
      end

      it 'formats dates correctly' do
        result = described_class.new.call

        # Dates should be in format "DD MMM"
        date_format = /^\d{2} [A-Za-z]{3}$/
        expect(result[:dates].all? { |date| date =~ date_format }).to be true

        # Last date should be today
        expect(result[:dates].last).to eq(Time.zone.today.strftime("%d %b"))
      end

      context 'when filtered by target_id' do
        let!(:other_target) { create(:target) }

        before do
          # Create reports for another target
          create(:report, target: other_target, scan: scan, created_at: Time.zone.today)
          create(:report, target: other_target, scan: scan, created_at: 5.days.ago)
        end

        it 'only includes reports for the specified target' do
          result = described_class.new(target_id: target.id).call

          # Should still have a total of 6 reports for our main target
          expect(result[:counts].last).to eq(6)

          # Check with the other target
          other_result = described_class.new(target_id: other_target.id).call

          # Should have 2 reports for the other target
          expect(other_result[:counts].last).to eq(2)
        end
      end

      context 'when filtered by scan_id' do
        let!(:other_scan) { create(:complete_scan) }

        before do
          # Create reports for another scan
          create(:report, target: target, scan: other_scan, created_at: Time.zone.today)
          create(:report, target: target, scan: other_scan, created_at: 7.days.ago)
        end

        it 'only includes reports for the specified scan' do
          result = described_class.new(scan_id: scan.id).call

          # Should have reports for our main scan
          expect(result[:counts].last).to be > 0

          # Check with the other scan
          other_result = described_class.new(scan_id: other_scan.id).call

          # Should have reports for the other scan
          expect(other_result[:counts].last).to be > 0

          # The difference between scan counts should be significant
          # (main scan should have more reports than other scan)
          expect(result[:counts].last).to be > other_result[:counts].last
        end
      end
    end
  end
end
