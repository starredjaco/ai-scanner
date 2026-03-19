require 'rails_helper'

RSpec.describe TaxonomyCategory, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:taxonomy_category)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to have_and_belong_to_many(:probes) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    describe 'uniqueness' do
      subject { TaxonomyCategory.new(name: 'Test Category') }
      it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    end
  end

  describe '.ransackable_attributes' do
    it 'returns the allowed attributes for ransack search' do
      expected_attributes = [ "created_at", "id", "id_value", "name", "updated_at" ]
      expect(TaxonomyCategory.ransackable_attributes).to match_array(expected_attributes)
    end
  end
end
