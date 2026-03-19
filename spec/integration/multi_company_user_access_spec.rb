# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-Company User Access', type: :model do
  describe 'user with multiple company memberships' do
    let!(:company_a) { create(:company, name: "Company A") }
    let!(:company_b) { create(:company, name: "Company B") }
    let!(:user) { create(:user, :without_company) }

    before do
      create(:membership, user: user, company: company_a)
      create(:membership, user: user, company: company_b)
      user.update!(current_company: company_a)
    end

    it 'user can belong to multiple companies' do
      expect(user.companies).to include(company_a, company_b)
    end

    it 'current_company determines active context' do
      expect(user.current_company).to eq(company_a)
    end

    it 'can switch between companies' do
      user.update!(current_company: company_b)
      expect(user.current_company).to eq(company_b)
    end
  end

  describe 'data isolation between companies' do
    let!(:company_a) { create(:company) }
    let!(:company_b) { create(:company) }
    let!(:user) { create(:user, :without_company) }

    before do
      create(:membership, user: user, company: company_a)
      create(:membership, user: user, company: company_b)

      ActsAsTenant.with_tenant(company_a) do
        @target_a = create(:target, company: company_a, name: "Target A")
      end
      ActsAsTenant.with_tenant(company_b) do
        @target_b = create(:target, company: company_b, name: "Target B")
      end
    end

    it 'sees only company_a targets in company_a context' do
      ActsAsTenant.with_tenant(company_a) do
        expect(Target.all).to include(@target_a)
        expect(Target.all).not_to include(@target_b)
      end
    end

    it 'sees only company_b targets in company_b context' do
      ActsAsTenant.with_tenant(company_b) do
        expect(Target.all).to include(@target_b)
        expect(Target.all).not_to include(@target_a)
      end
    end
  end

  describe 'removing membership' do
    let!(:company_a) { create(:company) }
    let!(:company_b) { create(:company) }
    let!(:user) { create(:user, :without_company) }

    before do
      @membership_a = create(:membership, user: user, company: company_a)
      @membership_b = create(:membership, user: user, company: company_b)
      user.update!(current_company: company_a)
    end

    it 'user loses access when membership removed' do
      expect(user.companies).to include(company_b)

      @membership_b.destroy

      user.reload
      expect(user.companies).not_to include(company_b)
    end

    it 'still belongs to remaining company after removal' do
      @membership_b.destroy

      user.reload
      expect(user.companies).to include(company_a)
    end
  end
end
