# frozen_string_literal: true

require "rails_helper"

RSpec.describe Retention::Cleanup do
  let(:service) { described_class.new }

  describe "#call" do
    it "delegates to the configured retention strategy" do
      mock_strategy = instance_double(Retention::SimpleStrategy)
      expected_result = { companies_processed: 1, reports_deleted: 5, errors: [], timestamp: Time.current }
      allow(mock_strategy).to receive(:call).and_return(expected_result)

      allow(Scanner.configuration).to receive(:retention_strategy_class_constant)
        .and_return(class_double(Retention::SimpleStrategy, new: mock_strategy))

      result = service.call

      expect(mock_strategy).to have_received(:call)
      expect(result).to eq(expected_result)
    end
  end

  # Integration tests - these exercise the full pipeline through Odin::TierRetention.
  describe "integration with tier-based retention (engine loaded)", if: defined?(Odin::TierRetention) do
    before do
      Scanner.configuration.retention_strategy_class = "Odin::TierRetention"
    end

    after do
      Scanner.configuration.retention_strategy_class = "Retention::SimpleStrategy"
    end

    # Helper to create reports with specific age and status
    def create_old_report(company:, days_ago:, status: :completed)
      report = create(:report, status, company: company)
      report.update_columns(created_at: days_ago.days.ago)
      report
    end

    context "with free tier company (7 day retention)" do
      let(:company) { create(:company, :free) }

      it "deletes completed reports older than 7 days" do
        old_report = create_old_report(company: company, days_ago: 8, status: :completed)
        recent_report = create_old_report(company: company, days_ago: 5, status: :completed)

        result = service.call

        expect(Report.exists?(old_report.id)).to be false
        expect(Report.exists?(recent_report.id)).to be true
        expect(result[:reports_deleted]).to eq(1)
      end

      it "does NOT delete pending reports regardless of age" do
        old_pending = create(:report, company: company, status: :pending)
        old_pending.update_columns(created_at: 30.days.ago)

        result = service.call

        expect(Report.exists?(old_pending.id)).to be true
        expect(result[:reports_deleted]).to eq(0)
      end
    end

    context "with enterprise tier company (unlimited retention)" do
      let(:company) { create(:company, :enterprise) }

      it "does NOT delete any reports regardless of age" do
        very_old_report = create_old_report(company: company, days_ago: 1000, status: :completed)

        result = service.call

        expect(Report.exists?(very_old_report.id)).to be true
        expect(result[:reports_deleted]).to eq(0)
      end
    end

    context "with multiple companies of different tiers" do
      it "applies correct retention per company tier" do
        free_company = create(:company, :free)
        enterprise_company = create(:company, :enterprise)

        free_old = create_old_report(company: free_company, days_ago: 10, status: :completed)
        enterprise_old = create_old_report(company: enterprise_company, days_ago: 500, status: :completed)

        result = service.call

        expect(Report.exists?(free_old.id)).to be false
        expect(Report.exists?(enterprise_old.id)).to be true
      end
    end

    context "grace period handling" do
      let(:company) do
        create(:company, :free, downgrade_date: 30.days.ago.to_date)
      end

      it "uses extended retention when grace period active" do
        within_grace_report = create_old_report(company: company, days_ago: 50)
        old_report = create_old_report(company: company, days_ago: 100)

        result = service.call

        expect(Report.exists?(within_grace_report.id)).to be true
        expect(Report.exists?(old_report.id)).to be false
      end
    end

    context "error handling" do
      it "handles empty database gracefully" do
        result = service.call

        expect(result[:companies_processed]).to eq(0)
        expect(result[:reports_deleted]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end
  end
end
