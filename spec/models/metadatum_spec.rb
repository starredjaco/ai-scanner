require 'rails_helper'

RSpec.describe Metadatum, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:key) }

    describe 'uniqueness' do
      subject { create(:metadatum) }
      it { is_expected.to validate_uniqueness_of(:key) }
    end
  end

  describe '.ransackable_attributes' do
    it 'returns the correct attributes' do
      expect(Metadatum.ransackable_attributes).to match_array([
        "created_at", "id", "key", "updated_at", "value"
      ])
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:metadatum)).to be_valid
    end

    it 'assigns unique keys' do
      metadata1 = create(:metadatum)
      metadata2 = create(:metadatum)

      expect(metadata1.key).not_to eq(metadata2.key)
    end
  end
end
