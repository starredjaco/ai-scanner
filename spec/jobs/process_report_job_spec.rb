# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessReportJob, type: :job do
  describe "#perform" do
    let(:company) { create(:company) }
    let(:report) { create(:report, :running, company: company) }

    before do
      allow_any_instance_of(Reports::Process).to receive(:call)
    end

    it "calls Reports::Process with the report_id" do
      expect_any_instance_of(Reports::Process).to receive(:call)

      described_class.new.perform(report.id)
    end

    it "sets the tenant context" do
      tenant_during_call = nil
      allow_any_instance_of(Reports::Process).to receive(:call) do
        tenant_during_call = ActsAsTenant.current_tenant
      end

      described_class.new.perform(report.id)

      expect(tenant_during_call).to eq(company)
    end

    it "runs :after_report_process hooks after processing" do
      hook_called = false
      hook_context = nil

      Scanner.register_hook(:after_report_process) do |ctx|
        hook_called = true
        hook_context = ctx
      end

      described_class.new.perform(report.id)

      expect(hook_called).to be true
      expect(hook_context[:report]).to eq(report)
      expect(hook_context[:company]).to eq(company)
    ensure
      Scanner.configuration.hooks.delete(:after_report_process)
    end

    it "runs hooks inside the tenant context" do
      tenant_during_hook = nil

      Scanner.register_hook(:after_report_process) do |_ctx|
        tenant_during_hook = ActsAsTenant.current_tenant
      end

      described_class.new.perform(report.id)

      expect(tenant_during_hook).to eq(company)
    ensure
      Scanner.configuration.hooks.delete(:after_report_process)
    end
  end

  describe "queue configuration" do
    it "uses default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      retry_handlers = described_class.rescue_handlers
      expect(retry_handlers.map { |h| h[0].to_s }).to include("StandardError")
    end
  end
end
