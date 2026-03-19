# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:company) }
  end

  describe 'validations' do
    let(:company) { create(:company) }
    let(:user) { create(:user) }
    subject { Membership.create!(user: user, company: company) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:company_id).with_message('already belongs to this company') }
  end

  describe 'uniqueness constraint' do
    let(:company) { create(:company) }
    let(:user) { create(:user) }

    it 'allows a user to belong to a company once' do
      membership = Membership.create!(user: user, company: company)
      expect(membership).to be_persisted
    end

    it 'prevents duplicate memberships for the same user and company' do
      Membership.create!(user: user, company: company)

      duplicate = Membership.new(user: user, company: company)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('already belongs to this company')
    end

    it 'allows a user to belong to multiple companies' do
      company2 = create(:company)

      membership1 = Membership.create!(user: user, company: company)
      membership2 = Membership.create!(user: user, company: company2)

      expect(membership1).to be_persisted
      expect(membership2).to be_persisted
      expect(user.companies).to include(company, company2)
    end

    it 'allows multiple users to belong to the same company' do
      user2 = create(:user)

      membership1 = Membership.create!(user: user, company: company)
      membership2 = Membership.create!(user: user2, company: company)

      expect(membership1).to be_persisted
      expect(membership2).to be_persisted
      expect(company.users).to include(user, user2)
    end
  end

  describe 'ransackable attributes' do
    it 'exposes expected attributes for search' do
      expect(Membership.ransackable_attributes).to include('id', 'user_id', 'company_id', 'created_at', 'updated_at')
    end

    it 'exposes expected associations for search' do
      expect(Membership.ransackable_associations).to include('user', 'company')
    end
  end
end
