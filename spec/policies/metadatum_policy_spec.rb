# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadatumPolicy do
  let(:company) { create(:company) }
  let(:user) { create(:user, current_company: company) }
  let(:metadatum) { create(:metadatum) }

  describe 'inheritance' do
    it 'inherits from TenantScopedPolicy' do
      expect(described_class.superclass).to eq(TenantScopedPolicy)
    end
  end

  describe 'permissions' do
    context 'as a regular user' do
      subject { described_class.new(user, metadatum) }

      it { is_expected.to be_index }
      it { is_expected.to be_show }
      it { is_expected.not_to be_create }
      it { is_expected.not_to be_update }
      it { is_expected.not_to be_destroy }
    end

    context 'as a super admin' do
      let(:super_admin) { create(:user, current_company: company, super_admin: true) }
      subject { described_class.new(super_admin, metadatum) }

      it { is_expected.to be_index }
      it { is_expected.to be_show }
      it { is_expected.to be_create }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
    end
  end

  describe 'Scope' do
    # Metadatum doesn't have acts_as_tenant - it's a global resource
    let!(:meta1) { create(:metadatum) }
    let!(:meta2) { create(:metadatum) }

    it 'returns all metadata (global resource)' do
      scope = described_class::Scope.new(user, Metadatum).resolve
      expect(scope).to include(meta1, meta2)
    end
  end
end
