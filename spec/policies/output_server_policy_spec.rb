# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutputServerPolicy do
  let(:other_company) { create(:company) }
  let(:output_server) { ActsAsTenant.with_tenant(company) { create(:output_server, company: company) } }

  describe 'inheritance' do
    let(:company) { create(:company, tier: :tier_3) }

    it 'inherits from TenantScopedPolicy' do
      expect(described_class.superclass).to eq(TenantScopedPolicy)
    end
  end

  describe 'Scope' do
    let(:company) { create(:company, tier: :tier_3) }
    let(:user) { create(:user, company: company) }
    let!(:own_server) { ActsAsTenant.with_tenant(company) { create(:output_server, company: company) } }
    let!(:other_server) { ActsAsTenant.with_tenant(other_company) { create(:output_server, company: other_company) } }

    it 'scopes output servers to current tenant' do
      ActsAsTenant.with_tenant(company) do
        scope = described_class::Scope.new(user, OutputServer).resolve
        expect(scope).to include(own_server)
        expect(scope).not_to include(other_server)
      end
    end
  end
end
