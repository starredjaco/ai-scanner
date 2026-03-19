# frozen_string_literal: true

require "rails_helper"

RSpec.describe SwitchCompanyController, type: :controller do
  let!(:company_a) { create(:company, name: "Company A") }
  let!(:company_b) { create(:company, name: "Company B") }
  let!(:user) { create(:user, :without_company) }

  before do
    create(:membership, user: user, company: company_a)
    create(:membership, user: user, company: company_b)
    user.update!(current_company: company_a)
    sign_in user
  end

  describe "PATCH #update" do
    it "switches to a company the user belongs to" do
      patch :update, params: { id: company_b.id }

      expect(user.reload.current_company).to eq(company_b)
      expect(flash[:notice]).to include("Company B")
      expect(response).to redirect_to(root_path)
    end

    it "does not switch to a company the user doesn't belong to" do
      other_company = create(:company, name: "Other Company")

      patch :update, params: { id: other_company.id }

      expect(user.reload.current_company).to eq(company_a)
      expect(flash[:alert]).to be_present
    end

    it "handles non-existent company gracefully" do
      patch :update, params: { id: 999999 }

      expect(user.reload.current_company).to eq(company_a)
      expect(flash[:alert]).to be_present
    end

    it "redirects back to previous page when referer is set" do
      request.env["HTTP_REFERER"] = "/scans"

      patch :update, params: { id: company_b.id }

      expect(response).to redirect_to("/scans")
    end

    it "switches company even when user has invalid time zone" do
      user.update_column(:time_zone, "America/New_York")

      patch :update, params: { id: company_b.id }

      expect(user.reload.current_company).to eq(company_b)
      expect(flash[:notice]).to include("Company B")
    end
  end
end
