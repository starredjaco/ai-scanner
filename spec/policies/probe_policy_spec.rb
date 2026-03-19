# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProbePolicy do
  let(:company) { create(:company) }
  let(:regular_user) { create(:user, current_company: company) }
  let(:super_admin) { create(:user, :super_admin, current_company: company) }

  let!(:enabled_probes) do
    (1..10).map { |i| create(:probe, name: "Probe #{i}", enabled: true) }
  end

  let!(:disabled_probe) { create(:probe, name: "Disabled Probe", enabled: false) }

  # Use base ProbeAccess (not engine's tier-based override) to test policy logic
  around do |example|
    original = Scanner.configuration.probe_access_class
    Scanner.configuration.probe_access_class = "ProbeAccess"
    example.run
    Scanner.configuration.probe_access_class = original
  end

  describe "#index?" do
    it "allows any user" do
      expect(described_class.new(regular_user, Probe).index?).to be true
    end
  end

  describe "#show?" do
    context "for super admin" do
      it "allows access to any probe" do
        ActsAsTenant.with_tenant(company) do
          expect(described_class.new(super_admin, enabled_probes.first).show?).to be true
        end
      end
    end

    context "for regular user" do
      it "allows access to any enabled probe" do
        ActsAsTenant.with_tenant(company) do
          expect(described_class.new(regular_user, enabled_probes.first).show?).to be true
        end
      end

      it "denies access to disabled probe" do
        ActsAsTenant.with_tenant(company) do
          expect(described_class.new(regular_user, disabled_probe).show?).to be false
        end
      end
    end
  end

  describe "Scope" do
    context "for super admin" do
      it "returns all probes" do
        ActsAsTenant.with_tenant(company) do
          scope = described_class::Scope.new(super_admin, Probe).resolve
          expect(scope.count).to eq(11)
        end
      end
    end

    context "for regular user" do
      it "returns only enabled probes (OSS mode)" do
        ActsAsTenant.with_tenant(company) do
          scope = described_class::Scope.new(regular_user, Probe).resolve
          expect(scope.count).to eq(10)
        end
      end
    end

    context "without tenant context" do
      it "returns no probes" do
        ActsAsTenant.without_tenant do
          scope = described_class::Scope.new(regular_user, Probe).resolve
          expect(scope.count).to eq(0)
        end
      end
    end
  end
end
