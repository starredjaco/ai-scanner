# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::GlossaryController, type: :controller do
  render_views

  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }

  before do
    user.update!(current_company: company)
    sign_in user
    ActsAsTenant.current_tenant = company
  end

  describe "GET #show" do
    it "returns success" do
      get :show
      expect(response).to have_http_status(:success)
    end

    it "displays glossary sections" do
      get :show
      expect(response.body).to include("Scanning Workflow")
      expect(response.body).to include("Metrics & Scoring")
    end
  end
end
