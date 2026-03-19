# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnvironmentVariablePolicy do
  let(:company) { create(:company) }
  let(:user) { create(:user, current_company: company) }
  let(:target) { ActsAsTenant.with_tenant(company) { create(:target, company: company) } }
  let(:env_var) { create(:environment_variable, target: target) }

  describe 'inheritance' do
    it 'inherits from TenantScopedPolicy' do
      expect(described_class.superclass).to eq(TenantScopedPolicy)
    end
  end

  describe 'inherited permissions from TenantScopedPolicy' do
    subject { described_class.new(user, env_var) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
    it { is_expected.to be_destroy }
  end

  describe 'custom actions' do
    subject { described_class.new(user, env_var) }

    describe '#batch_destroy?' do
      it 'allows batch destroying environment variables' do
        expect(subject.batch_destroy?).to be true
      end
    end
  end

  describe 'Scope' do
    let(:other_company) { create(:company) }
    let!(:own_target) { ActsAsTenant.with_tenant(company) { create(:target, company: company) } }
    let!(:own_env_var) { ActsAsTenant.with_tenant(company) { create(:environment_variable, target: own_target) } }
    let!(:own_global_env_var) { ActsAsTenant.with_tenant(company) { create(:environment_variable, target: nil) } }
    let!(:other_env_var) { ActsAsTenant.with_tenant(other_company) { create(:environment_variable, target: nil) } }

    it 'returns only current tenant environment variables' do
      ActsAsTenant.with_tenant(company) do
        scope = described_class::Scope.new(user, EnvironmentVariable).resolve
        expect(scope).to include(own_env_var, own_global_env_var)
        expect(scope).not_to include(other_env_var)
      end
    end
  end
end
