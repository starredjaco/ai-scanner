# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImpersonationPolicy do
  let(:company_a) { create(:company) }
  let(:company_b) { create(:company) }
  let(:super_admin) { create(:user, :super_admin, company: company_a) }
  let(:other_super_admin) { create(:user, :super_admin, company: company_b) }
  let(:regular_user) { create(:user, company: company_a) }
  let(:other_company_user) { create(:user, company: company_b) }

  describe "#create?" do
    context "as super admin" do
      it "allows impersonating a regular user" do
        expect(described_class.new(super_admin, regular_user).create?).to be true
      end

      it "allows impersonating a user from another company" do
        expect(described_class.new(super_admin, other_company_user).create?).to be true
      end

      it "denies impersonating another super admin" do
        expect(described_class.new(super_admin, other_super_admin).create?).to be false
      end

      it "denies impersonating self" do
        expect(described_class.new(super_admin, super_admin).create?).to be false
      end
    end

    context "as regular user" do
      it "denies impersonating any user" do
        expect(described_class.new(regular_user, other_company_user).create?).to be false
      end

      it "denies impersonating same company user" do
        same_company_user = create(:user, company: company_a)
        expect(described_class.new(regular_user, same_company_user).create?).to be false
      end

      it "denies impersonating super admin" do
        expect(described_class.new(regular_user, super_admin).create?).to be false
      end
    end
  end

  describe "#destroy?" do
    it "allows anyone to stop impersonating" do
      expect(described_class.new(super_admin, regular_user).destroy?).to be true
      expect(described_class.new(regular_user, other_company_user).destroy?).to be true
    end
  end
end
