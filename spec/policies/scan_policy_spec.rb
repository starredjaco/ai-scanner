# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanPolicy do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, current_company: company) }

  describe 'inheritance' do
    it 'inherits from TenantScopedPolicy' do
      expect(described_class.superclass).to eq(TenantScopedPolicy)
    end
  end

  describe 'inherited permissions from TenantScopedPolicy' do
    let(:scan) do
      ActsAsTenant.with_tenant(company) do
        create(:complete_scan, company: company)
      end
    end
    subject { described_class.new(user, scan) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
    it { is_expected.to be_destroy }
  end

  describe 'custom actions' do
    let(:scan) do
      ActsAsTenant.with_tenant(company) do
        create(:complete_scan, company: company)
      end
    end
    subject { described_class.new(user, scan) }

    describe '#rerun?' do
      it 'allows rerunning a scan' do
        expect(subject.rerun?).to be true
      end
    end

    describe '#stats?' do
      it 'allows viewing stats' do
        expect(subject.stats?).to be true
      end
    end

    describe '#batch_rerun?' do
      it 'allows batch rerunning scans' do
        expect(subject.batch_rerun?).to be true
      end
    end

    describe '#batch_destroy?' do
      it 'allows batch destroying scans' do
        expect(subject.batch_destroy?).to be true
      end
    end
  end

  describe 'Scope' do
    let!(:own_scan) do
      ActsAsTenant.with_tenant(company) do
        create(:complete_scan, company: company)
      end
    end
    let!(:other_scan) do
      ActsAsTenant.with_tenant(other_company) do
        create(:complete_scan, company: other_company)
      end
    end

    it 'scopes scans to current tenant' do
      ActsAsTenant.with_tenant(company) do
        scope = described_class::Scope.new(user, Scan).resolve
        expect(scope).to include(own_scan)
        expect(scope).not_to include(other_scan)
      end
    end
  end
end
