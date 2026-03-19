# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ReportsController, type: :controller do
  render_views

  let!(:company) { create(:company, tier: :tier_4) }
  let!(:super_admin) { create(:user, :super_admin, company: company) }
  let!(:report) do
    ActsAsTenant.with_tenant(company) do
      create(:report, :completed, company: company)
    end
  end

  before do
    super_admin.update!(current_company: company)
    sign_in super_admin
    ActsAsTenant.current_tenant = company
  end

  describe "GET #show" do
    it "returns success" do
      get :show, params: { id: report.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #probes_tab" do
    it "returns success" do
      get :probes_tab, params: { id: report.id }
      expect(response).to have_http_status(:success)
    end

    it "renders without layout" do
      get :probes_tab, params: { id: report.id }
      # layout: false means no <html> or <body> tags wrapping the response
      expect(response.body).not_to include("<!DOCTYPE html>")
    end

    it "wraps content in a turbo frame" do
      get :probes_tab, params: { id: report.id }
      expect(response.body).to include('turbo-frame')
      expect(response.body).to include('report-probes-tab')
    end

    context "with probe results" do
      let!(:probe_result) do
        ActsAsTenant.with_tenant(company) do
          create(:probe_result, report: report)
        end
      end

      it "renders probe results content" do
        get :probes_tab, params: { id: report.id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET #attempt_content" do
    let!(:probe_result) do
      ActsAsTenant.with_tenant(company) do
        create(:probe_result, report: report, attempts: [
          { "prompt" => "test prompt text", "outputs" => [ "test response text" ], "notes" => { "score_percentage" => 50 } }
        ])
      end
    end

    it "returns success for valid attempt" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: 0 }
      expect(response).to have_http_status(:success)
    end

    it "renders without layout" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: 0 }
      expect(response.body).not_to include("<!DOCTYPE html>")
    end

    it "wraps content in a turbo frame" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: 0 }
      expect(response.body).to include("turbo-frame")
      expect(response.body).to include("attempt-content-#{probe_result.id}-0")
    end

    it "includes prompt and response text" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: 0 }
      expect(response.body).to include("test prompt text")
      expect(response.body).to include("test response text")
    end

    it "returns not found for invalid attempt index" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: 999 }
      expect(response).to have_http_status(:not_found)
    end

    it "returns bad request for negative attempt index" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: -1 }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request for non-numeric attempt index" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id, attempt_index: "abc" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request for missing attempt index" do
      get :attempt_content, params: { id: report.id, probe_result_id: probe_result.id }
      expect(response).to have_http_status(:bad_request)
    end

    it "raises not found for probe_result from another report" do
      other_report = ActsAsTenant.with_tenant(company) { create(:report, :completed, company: company) }
      other_pr = ActsAsTenant.with_tenant(company) { create(:probe_result, report: other_report) }
      expect {
        get :attempt_content, params: { id: report.id, probe_result_id: other_pr.id, attempt_index: 0 }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context "when probe_result has no attempts" do
      let!(:empty_probe_result) do
        ActsAsTenant.with_tenant(company) do
          create(:probe_result, report: report, attempts: nil)
        end
      end

      it "returns not found for index 0" do
        get :attempt_content, params: { id: report.id, probe_result_id: empty_probe_result.id, attempt_index: 0 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "cross-tenant isolation" do
    let!(:other_company) { create(:company) }
    let!(:other_report) do
      ActsAsTenant.with_tenant(other_company) do
        create(:report, :completed, company: other_company)
      end
    end

    it "probes_tab cannot access a report from another tenant" do
      expect {
        get :probes_tab, params: { id: other_report.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "attempt_content cannot access a report from another tenant" do
      other_probe_result = ActsAsTenant.with_tenant(other_company) { create(:probe_result, report: other_report) }
      expect {
        get :attempt_content, params: { id: other_report.id, probe_result_id: other_probe_result.id, attempt_index: 0 }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
