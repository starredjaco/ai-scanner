# frozen_string_literal: true

require "rails_helper"

RSpec.describe Retention::SimpleStrategy do
  let(:service) { described_class.new }

  # Helper to create reports with specific age and status
  def create_old_report(company:, days_ago:, status: :completed)
    report = create(:report, status, company: company)
    report.update_columns(created_at: days_ago.days.ago)
    report
  end

  describe "#call" do
    context "with default 90-day retention" do
      let(:company) { create(:company) }

      it "deletes completed reports older than 90 days" do
        old_report = create_old_report(company: company, days_ago: 95, status: :completed)
        recent_report = create_old_report(company: company, days_ago: 80, status: :completed)

        result = service.call

        expect(Report.exists?(old_report.id)).to be false
        expect(Report.exists?(recent_report.id)).to be true
        expect(result[:reports_deleted]).to eq(1)
      end

      it "deletes failed reports older than retention period" do
        old_failed = create_old_report(company: company, days_ago: 95, status: :failed)

        result = service.call

        expect(Report.exists?(old_failed.id)).to be false
        expect(result[:reports_deleted]).to eq(1)
      end

      it "deletes stopped reports older than retention period" do
        old_stopped = create_old_report(company: company, days_ago: 95, status: :stopped)

        result = service.call

        expect(Report.exists?(old_stopped.id)).to be false
        expect(result[:reports_deleted]).to eq(1)
      end

      it "does NOT delete pending reports regardless of age" do
        old_pending = create(:report, company: company, status: :pending)
        old_pending.update_columns(created_at: 100.days.ago)

        result = service.call

        expect(Report.exists?(old_pending.id)).to be true
        expect(result[:reports_deleted]).to eq(0)
      end

      it "does NOT delete running reports regardless of age" do
        old_running = create(:report, :running, company: company)
        old_running.update_columns(created_at: 100.days.ago)

        result = service.call

        expect(Report.exists?(old_running.id)).to be true
      end

      it "keeps reports within the retention window" do
        report_85_days = create_old_report(company: company, days_ago: 85, status: :completed)

        result = service.call

        expect(Report.exists?(report_85_days.id)).to be true
        expect(result[:reports_deleted]).to eq(0)
      end
    end

    context "with custom RETENTION_DAYS env" do
      around do |example|
        original = ENV["RETENTION_DAYS"]
        ENV["RETENTION_DAYS"] = "30"
        example.run
      ensure
        if original
          ENV["RETENTION_DAYS"] = original
        else
          ENV.delete("RETENTION_DAYS")
        end
      end

      it "uses the configured retention period" do
        company = create(:company)
        old_report = create_old_report(company: company, days_ago: 35, status: :completed)
        recent_report = create_old_report(company: company, days_ago: 25, status: :completed)

        result = service.call

        expect(Report.exists?(old_report.id)).to be false
        expect(Report.exists?(recent_report.id)).to be true
      end
    end

    context "applies same retention to all companies regardless of tier" do
      it "treats all companies equally" do
        free_company = create(:company, :free)
        enterprise_company = create(:company, :enterprise)

        free_old = create_old_report(company: free_company, days_ago: 95, status: :completed)
        enterprise_old = create_old_report(company: enterprise_company, days_ago: 95, status: :completed)

        result = service.call

        # Both should be deleted - no tier distinction
        expect(Report.exists?(free_old.id)).to be false
        expect(Report.exists?(enterprise_old.id)).to be false
        expect(result[:companies_processed]).to eq(2)
        expect(result[:reports_deleted]).to eq(2)
      end
    end

    context "with multiple companies" do
      it "returns accurate statistics" do
        company1 = create(:company)
        company2 = create(:company)

        2.times { create_old_report(company: company1, days_ago: 95, status: :completed) }
        3.times { create_old_report(company: company2, days_ago: 95, status: :completed) }

        result = service.call

        expect(result[:companies_processed]).to eq(2)
        expect(result[:reports_deleted]).to eq(5)
        expect(result[:timestamp]).to be_a(Time)
      end
    end

    context "edge cases" do
      it "handles empty database gracefully" do
        result = service.call

        expect(result[:companies_processed]).to eq(0)
        expect(result[:reports_deleted]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it "handles company with no reports" do
        create(:company)

        result = service.call

        expect(result[:companies_processed]).to eq(0)
        expect(result[:reports_deleted]).to eq(0)
      end
    end

    context "error handling" do
      let(:company1) { create(:company) }
      let(:company2) { create(:company) }

      it "continues processing other companies when one fails" do
        create_old_report(company: company1, days_ago: 95, status: :completed)
        create_old_report(company: company2, days_ago: 95, status: :completed)

        call_count = 0
        allow_any_instance_of(Report).to receive(:destroy) do |report|
          call_count += 1
          if report.company_id == company1.id
            raise StandardError, "Simulated error"
          else
            report.delete
          end
        end

        result = service.call

        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first[:company_id]).to eq(company1.id)
      end
    end

    context "data integrity - cascading deletes" do
      let(:company) { create(:company) }

      it "deletes associated probe_results" do
        report = create_old_report(company: company, days_ago: 95, status: :completed)
        probe_result = create(:probe_result, report: report)

        service.call

        expect(Report.exists?(report.id)).to be false
        expect(ProbeResult.exists?(probe_result.id)).to be false
      end
    end
  end

  describe "CLEANUP_SAFE_STATUSES" do
    it "includes completed, failed, and stopped" do
      expect(described_class::CLEANUP_SAFE_STATUSES).to contain_exactly("completed", "failed", "stopped")
    end
  end

  describe "DEFAULT_RETENTION_DAYS" do
    it "is 90 days" do
      expect(described_class::DEFAULT_RETENTION_DAYS).to eq(90)
    end
  end
end
