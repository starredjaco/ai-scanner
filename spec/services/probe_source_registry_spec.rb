require 'rails_helper'

RSpec.describe ProbeSourceRegistry do
  after { described_class.reset! }

  describe '.register' do
    it 'adds a source class' do
      described_class.reset!
      described_class.register(GarakCommunityProbeSource)

      expect(described_class.sources).to include(GarakCommunityProbeSource)
    end

    it 'does not add duplicates' do
      described_class.reset!
      described_class.register(GarakCommunityProbeSource)
      described_class.register(GarakCommunityProbeSource)

      expect(described_class.sources.count { |s| s == GarakCommunityProbeSource }).to eq(1)
    end
  end

  describe '.sources' do
    it 'returns an array' do
      expect(described_class.sources).to be_an(Array)
    end
  end

  describe '.reset!' do
    it 'clears all registered sources' do
      described_class.register(GarakCommunityProbeSource)
      described_class.reset!

      expect(described_class.sources).to be_empty
    end
  end
end
