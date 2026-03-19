require 'rails_helper'

RSpec.describe Stats::ProbeDisclosureStats do
  describe '#call' do
    subject { described_class.new.call }

    context 'when there are probes with different disclosure statuses' do
      before do
        create_list(:probe, 3, disclosure_status: "0-day")
        create_list(:probe, 7, disclosure_status: "n-day")
      end

      it 'returns labels and values for each disclosure status' do
        expect(subject).to eq({
          labels: [ "0-day", "n-day" ],
          values: [ 3, 7 ]
        })
      end

      it 'uses a single GROUP BY query instead of N+1' do
        # Verify efficient query pattern (1 query total)
        queries = []
        callback = ->(event) { queries << event.payload[:sql] }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          subject
        end

        probe_queries = queries.select { |q| q.include?("probes") && !q.include?("SCHEMA") }
        expect(probe_queries.size).to eq(1)
        expect(probe_queries.first).to include("GROUP BY")
      end
    end

    context 'when there are no probes' do
      it 'returns zeros for all values' do
        expect(subject).to eq({
          labels: [ "0-day", "n-day" ],
          values: [ 0, 0 ]
        })
      end
    end

    context 'when only one status has probes' do
      before do
        create_list(:probe, 5, disclosure_status: "0-day")
      end

      it 'returns zero for missing status' do
        expect(subject).to eq({
          labels: [ "0-day", "n-day" ],
          values: [ 5, 0 ]
        })
      end
    end
  end
end
