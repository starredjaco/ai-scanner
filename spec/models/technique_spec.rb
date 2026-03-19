require 'rails_helper'

RSpec.describe Technique, type: :model do
  describe 'validations' do
    describe 'name validations' do
      subject { build(:technique) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_uniqueness_of(:name) }
    end

    describe 'path validations' do
      subject { build(:technique) }
      it { is_expected.to validate_uniqueness_of(:path) }

      it 'validates presence of path' do
        technique = build(:technique, name: 'Test', path: '')
        expect(technique).to be_valid
        technique.valid?
        expect(technique.path).not_to be_blank
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_and_belong_to_many(:probes) }
  end

  describe 'callbacks' do
    it 'normalizes the path if blank before validation' do
      technique = build(:technique, name: 'Test Technique', path: '')
      technique.valid?
      expect(technique.path).to eq('test_technique')
    end

    it 'does not normalize the path if already set' do
      technique = build(:technique, name: 'Test Technique', path: 'custom-path')
      technique.valid?
      expect(technique.path).to eq('custom-path')
    end
  end

  describe '.ransackable_attributes' do
    it 'returns the correct attributes' do
      expect(Technique.ransackable_attributes).to match_array([
        "id", "id_value", "name", "path"
      ])
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:technique)).to be_valid
    end

    it 'generates unique names and paths' do
      technique1 = create(:technique)
      technique2 = create(:technique)

      expect(technique1.name).not_to eq(technique2.name)
      expect(technique1.path).not_to eq(technique2.path)
    end
  end
end
