require 'rails_helper'

RSpec.describe Stats::TaxonomyDistributionData, type: :service do
  describe '#call' do
    context 'when no taxonomy categories exist' do
      it 'returns empty data structures' do
        result = described_class.new.call

        expect(result[:categories]).to eq([])
        expect(result[:data]).to eq([])
      end
    end

    context 'when taxonomy categories exist without probes' do
      let!(:category1) { create(:taxonomy_category, name: 'Hallucination') }
      let!(:category2) { create(:taxonomy_category, name: 'Prompt Injection') }

      it 'returns categories with zero counts' do
        result = described_class.new.call

        expect(result[:categories]).to contain_exactly('Hallucination', 'Prompt Injection')
        expect(result[:data].size).to eq(2)
        expect(result[:data].pluck(:value)).to all(eq(0))
      end
    end

    context 'when taxonomy categories have probes' do
      let!(:category1) { create(:taxonomy_category, name: 'Hallucination') }
      let!(:category2) { create(:taxonomy_category, name: 'Prompt Injection') }
      let!(:category3) { create(:taxonomy_category, name: 'Data Leakage') }

      before do
        # Create probes with different taxonomies
        3.times do
          probe = create(:probe)
          probe.taxonomy_categories << category1
          probe.save
        end

        2.times do
          probe = create(:probe)
          probe.taxonomy_categories << category2
          probe.save
        end

        1.times do
          probe = create(:probe)
          probe.taxonomy_categories << category3
          probe.save
        end
      end

      it 'returns correct probe counts for each category' do
        result = described_class.new.call

        expect(result[:categories]).to contain_exactly('Hallucination', 'Prompt Injection', 'Data Leakage')

        # Find count for each category in the results
        hallucination_data = result[:data].find { |item| item[:name] == 'Hallucination' }
        prompt_injection_data = result[:data].find { |item| item[:name] == 'Prompt Injection' }
        data_leakage_data = result[:data].find { |item| item[:name] == 'Data Leakage' }

        expect(hallucination_data[:value]).to eq(3)
        expect(prompt_injection_data[:value]).to eq(2)
        expect(data_leakage_data[:value]).to eq(1)
      end

      it 'maintains alphabetical ordering by category name' do
        result = described_class.new.call

        # Extract category names in the order they appear in the result
        category_names = result[:data].map { |item| item[:name] }

        # Verify the order is alphabetical
        expect(category_names).to eq(category_names.sort)
      end
    end
  end
end
