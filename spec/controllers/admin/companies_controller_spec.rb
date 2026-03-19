# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CompaniesController, type: :controller do
  render_views

  let!(:company_a) { create(:company, name: "Alpha Corp", tier: :tier_2) }
  let!(:company_b) { create(:company, name: "Beta Inc", tier: :tier_3) }
  let!(:super_admin) { create(:user, :super_admin, company: company_a) }

  # Set up super admin authentication for all tests
  before do
    super_admin.update!(current_company: company_a)
    sign_in super_admin
    ActsAsTenant.current_tenant = company_a
  end

  describe "GET #index" do
    it "returns success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "displays all company names" do
      get :index
      expect(response.body).to include("Alpha Corp")
      expect(response.body).to include("Beta Inc")
    end

    it "supports ransack search filtering" do
      get :index, params: { q: { name_cont: "Alpha" } }
      expect(response.body).to include("Alpha Corp")
      expect(response.body).not_to include("Beta Inc")
    end
  end

  describe "GET #show" do
    it "returns success" do
      get :show, params: { id: company_a.id }
      expect(response).to have_http_status(:success)
    end

    it "displays company name" do
      get :show, params: { id: company_a.id }
      expect(response.body).to include("Alpha Corp")
    end

    it "can view any company (super admin can access all)" do
      get :show, params: { id: company_b.id }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Beta Inc")
    end
  end

  describe "GET #new" do
    it "returns success" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    it "creates a new company with valid params" do
      expect {
        post :create, params: { company: { name: "New Corp", tier: "tier_1" } }
      }.to change(Company, :count).by(1)

      expect(response).to redirect_to(company_path(Company.last))
      expect(flash[:notice]).to eq("Company was successfully created.")
    end

    it "does not create with invalid params" do
      expect {
        post :create, params: { company: { name: "", tier: "tier_1" } }
      }.not_to change(Company, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET #edit" do
    it "returns success" do
      get :edit, params: { id: company_a.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH #update" do
    it "updates company with valid params" do
      patch :update, params: { id: company_a.id, company: { name: "Updated Corp" } }

      expect(response).to redirect_to(company_path(company_a))
      expect(company_a.reload.name).to eq("Updated Corp")
      expect(flash[:notice]).to eq("Company was successfully updated.")
    end

    it "does not update with invalid params" do
      patch :update, params: { id: company_a.id, company: { name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(company_a.reload.name).to eq("Alpha Corp")
    end
  end

  describe "DELETE #destroy" do
    it "deletes the company" do
      expect {
        delete :destroy, params: { id: company_b.id }
      }.to change(Company, :count).by(-1)

      expect(response).to redirect_to(companies_path)
      expect(flash[:notice]).to eq("Company was successfully deleted.")
    end
  end
end

# Note: Authorization denial tests are handled by CompanyPolicy spec
# Regular users cannot access these routes per CompanyPolicy
