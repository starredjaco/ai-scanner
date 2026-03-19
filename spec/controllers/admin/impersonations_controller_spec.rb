# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ImpersonationsController, type: :controller do
  let!(:company_a) { create(:company, name: "Company A") }
  let!(:company_b) { create(:company, name: "Company B") }
  let!(:super_admin) { create(:user, :super_admin, company: company_a) }
  let!(:regular_user) { create(:user, company: company_a) }
  let!(:other_company_user) { create(:user, company: company_b) }

  # Set up super admin authentication
  before do
    super_admin.update!(current_company: company_a)
    sign_in super_admin
    ActsAsTenant.current_tenant = company_a
  end

  describe "POST #create" do
    it "starts impersonation of regular user" do
      post :create, params: { id: regular_user.id }

      expect(session[:admin_user_id]).to eq(super_admin.id)
      expect(session[:impersonated_user_id]).to eq(regular_user.id)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include(regular_user.email)
    end

    it "can impersonate user from another company" do
      post :create, params: { id: other_company_user.id }

      expect(session[:impersonated_user_id]).to eq(other_company_user.id)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE #destroy" do
    context "when impersonating" do
      before do
        session[:admin_user_id] = super_admin.id
        session[:impersonated_user_id] = regular_user.id
      end

      it "stops impersonation" do
        delete :destroy

        expect(session[:admin_user_id]).to be_nil
        expect(session[:impersonated_user_id]).to be_nil
        expect(response).to redirect_to(users_path)
        expect(flash[:notice]).to include("admin session")
      end
    end

    context "when not impersonating" do
      it "redirects gracefully" do
        delete :destroy

        expect(response).to redirect_to(users_path)
      end
    end
  end
end

# Note: Authorization denial tests (regular user cannot impersonate,
# super admin cannot impersonate another super admin or self) are
# handled by ImpersonationPolicy spec
