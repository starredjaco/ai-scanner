require 'rails_helper'

RSpec.describe DetectorResult, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:detector) }
    it { is_expected.to belong_to(:report) }
  end

  describe 'validations' do
  end

  describe '.ransackable_attributes' do
    it 'returns the correct attributes' do
      expect(DetectorResult.ransackable_attributes).to match_array([
        "detector_id", "report_id", "passed", "total", "max_score",
        "created_at", "id", "updated_at"
      ])
    end
  end

  describe '.ransackable_associations' do
    it 'returns the correct associations' do
      expect(DetectorResult.ransackable_associations).to match_array([ "detector", "report" ])
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:detector_result)).to be_valid
    end
  end

  describe '#asr_percentage' do
    it 'calculates percentage correctly' do
      result = build_stubbed(:detector_result, passed: 25, total: 100)
      expect(result.asr_percentage).to eq(25)
    end

    it 'rounds to nearest integer' do
      result = build_stubbed(:detector_result, passed: 1, total: 3)
      expect(result.asr_percentage).to eq(33)
    end

    it 'returns 0 when total is zero' do
      result = build_stubbed(:detector_result, passed: 5, total: 0)
      expect(result.asr_percentage).to eq(0)
    end

    it 'returns 0 when total is nil' do
      result = build_stubbed(:detector_result, passed: 5, total: nil)
      expect(result.asr_percentage).to eq(0)
    end

    it 'returns 100 when all tests pass' do
      result = build_stubbed(:detector_result, passed: 10, total: 10)
      expect(result.asr_percentage).to eq(100)
    end

    it 'returns 0 when no tests pass' do
      result = build_stubbed(:detector_result, passed: 0, total: 10)
      expect(result.asr_percentage).to eq(0)
    end
  end
end
