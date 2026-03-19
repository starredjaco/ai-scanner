# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProbeAccess do
  let(:company) { create(:company) }
  let(:service) { described_class.new(company) }

  describe "#accessible_probes" do
    it "returns all enabled probes" do
      enabled = create(:probe, enabled: true)
      disabled = create(:probe, enabled: false)

      result = service.accessible_probes

      expect(result).to include(enabled)
      expect(result).not_to include(disabled)
    end

    it "returns empty relation when no probes exist" do
      expect(service.accessible_probes).to be_empty
    end

    it "includes probes regardless of disclosure status" do
      disclosed = create(:probe, disclosure_status: "n-day", enabled: true)
      undisclosed = create(:probe, disclosure_status: "0-day", enabled: true)

      result = service.accessible_probes

      expect(result).to include(disclosed, undisclosed)
    end
  end

  describe "#can_access?" do
    it "returns true for any enabled probe" do
      probe = create(:probe, enabled: true)
      expect(service.can_access?(probe)).to be true
    end

    it "returns false for disabled probe" do
      probe = create(:probe, enabled: false)
      expect(service.can_access?(probe)).to be false
    end

    it "returns false for nil probe" do
      expect(service.can_access?(nil)).to be false
    end
  end

  describe "#filter_accessible" do
    it "returns only enabled probes from the relation" do
      enabled_probe = create(:probe, enabled: true)
      disabled_probe = create(:probe, enabled: false)
      probes = Probe.where(id: [ enabled_probe.id, disabled_probe.id ])

      result = service.filter_accessible(probes)

      expect(result).to include(enabled_probe)
      expect(result).not_to include(disabled_probe)
    end

    it "preserves the relation type for chaining" do
      probes = Probe.all
      result = service.filter_accessible(probes)
      expect(result).to be_a(ActiveRecord::Relation)
    end
  end

  describe "#accessible_count" do
    it "returns count of all enabled probes" do
      create(:probe, enabled: true)
      create(:probe, enabled: true)
      create(:probe, enabled: false)

      expect(service.accessible_count).to eq(2)
    end

    it "returns 0 when no probes exist" do
      expect(service.accessible_count).to eq(0)
    end
  end
end
