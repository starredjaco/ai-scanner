# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::SettingsController, type: :controller do
  render_views

  let!(:company) { create(:company, tier: :tier_4) }
  let!(:super_admin) { create(:user, :super_admin, company: company) }
  let!(:regular_user) { create(:user, company: company) }

  describe "GET #show" do
    context "as super admin" do
      before do
        super_admin.update!(current_company: company)
        sign_in super_admin
        ActsAsTenant.current_tenant = company
      end

      it "returns success" do
        get :show
        expect(response).to have_http_status(:success)
      end

      it "shows all settings including super admin settings" do
        get :show
        expect(response.body).to include("Parallel Scans")
        # Super admin can see custom_header_html
      end
    end

    context "as regular user" do
      before do
        regular_user.update!(current_company: company)
        sign_in regular_user
        ActsAsTenant.current_tenant = company
      end

      it "is denied access" do
        get :show
        expect(flash[:alert]).to eq("Not authorized.")
      end
    end
  end

  describe "PATCH #update" do
    context "as super admin" do
      before do
        super_admin.update!(current_company: company)
        sign_in super_admin
        ActsAsTenant.current_tenant = company
      end

      it "updates parallel_scans_limit" do
        patch :update, params: { parallel_scans_limit: 10 }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to include("saved successfully")
      end

      it "validates parallel_scans_limit range" do
        patch :update, params: { parallel_scans_limit: 50 }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to include("between 1 and 20")
      end

      it "updates parallel_attempts" do
        patch :update, params: { parallel_attempts: 50 }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to include("saved successfully")
      end

      it "validates parallel_attempts range" do
        patch :update, params: { parallel_attempts: 200 }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to include("between 1 and 100")
      end

      it "can update portal_token (super admin only)" do
        patch :update, params: { portal_token: "new-token" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to include("saved successfully")
      end

      it "can update custom_header_html (super admin only)" do
        patch :update, params: { custom_header_html: "<div>Custom</div>" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to include("saved successfully")
      end
    end

    context "as regular user" do
      before do
        regular_user.update!(current_company: company)
        sign_in regular_user
        ActsAsTenant.current_tenant = company
      end

      it "is denied access" do
        patch :update, params: { parallel_scans_limit: 5 }
        expect(flash[:alert]).to eq("Not authorized.")
      end
    end
  end
end
