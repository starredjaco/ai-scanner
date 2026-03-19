# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompanyPolicy do
  let(:company_a) { create(:company) }
  let(:company_b) { create(:company) }
  let(:super_admin) { create(:user, :super_admin, company: company_a) }
  let(:regular_user) { create(:user, company: company_a) }

  describe "#index?" do
    it "allows super admin" do
      expect(described_class.new(super_admin, Company).index?).to be true
    end

    it "denies regular user" do
      expect(described_class.new(regular_user, Company).index?).to be false
    end
  end

  describe "#show?" do
    it "allows super admin to view any company" do
      expect(described_class.new(super_admin, company_b).show?).to be true
    end

    it "allows user to view their own company" do
      expect(described_class.new(regular_user, company_a).show?).to be true
    end

    it "denies user from viewing other company" do
      expect(described_class.new(regular_user, company_b).show?).to be false
    end
  end

  describe "#create?" do
    it "allows super admin" do
      expect(described_class.new(super_admin, Company.new).create?).to be true
    end

    it "denies regular user" do
      expect(described_class.new(regular_user, Company.new).create?).to be false
    end
  end

  describe "#update?" do
    it "allows super admin" do
      expect(described_class.new(super_admin, company_a).update?).to be true
    end

    it "denies regular user" do
      expect(described_class.new(regular_user, company_a).update?).to be false
    end
  end

  describe "#destroy?" do
    it "allows super admin" do
      expect(described_class.new(super_admin, company_a).destroy?).to be true
    end

    it "denies regular user" do
      expect(described_class.new(regular_user, company_a).destroy?).to be false
    end
  end

  describe "#menu_visible?" do
    it "allows super admin" do
      expect(described_class.new(super_admin, Company).menu_visible?).to be true
    end

    it "denies regular user" do
      expect(described_class.new(regular_user, Company).menu_visible?).to be false
    end
  end

  describe "Scope" do
    let!(:company_c) { create(:company) }

    context "for super admin" do
      it "returns all companies" do
        scope = described_class::Scope.new(super_admin, Company).resolve
        expect(scope).to include(company_a, company_b, company_c)
      end
    end

    context "for regular user" do
      it "returns only their own company" do
        scope = described_class::Scope.new(regular_user, Company).resolve
        expect(scope).to include(company_a)
        expect(scope).not_to include(company_b, company_c)
      end
    end
  end
end
