# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TargetPolicy do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, current_company: company) }
  let(:target) { ActsAsTenant.with_tenant(company) { create(:target, company: company) } }

  describe 'inheritance' do
    it 'inherits from TenantScopedPolicy' do
      expect(described_class.superclass).to eq(TenantScopedPolicy)
    end
  end

  describe 'inherited permissions from TenantScopedPolicy' do
    subject { described_class.new(user, target) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
    it { is_expected.to be_destroy }
  end

  describe 'custom actions' do
    subject { described_class.new(user, target) }

    describe '#validate?' do
      it 'allows validating a target' do
        expect(subject.validate?).to be true
      end
    end

    describe '#restore?' do
      it 'allows restoring a target' do
        expect(subject.restore?).to be true
      end
    end

    describe '#batch_validate?' do
      it 'allows batch validating targets' do
        expect(subject.batch_validate?).to be true
      end
    end

    describe '#batch_destroy?' do
      it 'allows batch destroying targets' do
        expect(subject.batch_destroy?).to be true
      end
    end

    describe '#auto_detect_selectors?' do
      it 'allows auto detecting selectors' do
        expect(subject.auto_detect_selectors?).to be true
      end
    end
  end

  describe 'Scope' do
    let!(:own_target) { ActsAsTenant.with_tenant(company) { create(:target, company: company) } }
    let!(:other_target) { ActsAsTenant.with_tenant(other_company) { create(:target, company: other_company) } }

    it 'scopes targets to current tenant' do
      ActsAsTenant.with_tenant(company) do
        scope = described_class::Scope.new(user, Target).resolve
        expect(scope).to include(own_target)
        expect(scope).not_to include(other_target)
      end
    end
  end
end
