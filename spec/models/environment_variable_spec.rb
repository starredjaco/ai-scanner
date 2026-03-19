require 'rails_helper'

RSpec.describe EnvironmentVariable, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:env_name) }
    it { is_expected.to validate_presence_of(:env_value) }

    describe 'uniqueness' do
      subject { create(:environment_variable) }
      it { is_expected.to validate_uniqueness_of(:env_name).scoped_to([ :company_id, :target_id ]) }
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:target).optional }
  end

  describe 'scopes' do
    describe '.global' do
      it 'returns environment variables without a target' do
        global_var = create(:global_environment_variable)
        target_var = create(:environment_variable, :with_target)

        expect(EnvironmentVariable.global).to include(global_var)
        expect(EnvironmentVariable.global).not_to include(target_var)
      end
    end
  end

  describe '.ransackable_attributes' do
    it 'returns the correct attributes' do
      expect(EnvironmentVariable.ransackable_attributes).to match_array([
        "created_at", "env_name", "id", "target_id", "updated_at"
      ])
    end
  end

  describe '.ransackable_associations' do
    it 'returns the correct associations' do
      expect(EnvironmentVariable.ransackable_associations).to match_array([ "target" ])
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:environment_variable)).to be_valid
    end

    it 'has a valid global factory' do
      expect(build(:global_environment_variable)).to be_valid
    end

    it 'can be associated with a target' do
      env_var = create(:environment_variable, :with_target)
      expect(env_var.target).to be_present
    end
  end
end
