require "rails_helper"

RSpec.describe BrandConfig do
  before { BrandConfig.reset! }
  after { BrandConfig.reset! }

  describe "defaults" do
    it "returns Scanner as brand_name" do
      expect(BrandConfig.brand_name).to eq("Scanner")
    end

    it "returns nil for logo_path" do
      expect(BrandConfig.logo_path).to be_nil
    end

    it "returns system-ui font family" do
      expect(BrandConfig.font_family).to eq("system-ui, sans-serif")
    end

    it "returns nil for powered_by" do
      expect(BrandConfig.powered_by).to be_nil
    end

    it "returns nil for host_url" do
      expect(BrandConfig.host_url).to be_nil
    end
  end

  describe ".configure" do
    it "overrides specific values while keeping defaults for others" do
      BrandConfig.configure(brand_name: "Custom Scanner", host_url: "https://example.com")

      expect(BrandConfig.brand_name).to eq("Custom Scanner")
      expect(BrandConfig.host_url).to eq("https://example.com")
      expect(BrandConfig.font_family).to eq("system-ui, sans-serif")
      expect(BrandConfig.powered_by).to be_nil
    end

    it "overrides all values" do
      BrandConfig.configure(
        brand_name:  "Test Scanner",
        logo_path:   "logos/custom-logo.svg",
        font_family: '"Custom Font", system-ui, sans-serif',
        powered_by:  "ACME",
        host_url:    "https://scanner.example.com"
      )

      expect(BrandConfig.brand_name).to eq("Test Scanner")
      expect(BrandConfig.logo_path).to eq("logos/custom-logo.svg")
      expect(BrandConfig.font_family).to eq('"Custom Font", system-ui, sans-serif')
      expect(BrandConfig.powered_by).to eq("ACME")
      expect(BrandConfig.host_url).to eq("https://scanner.example.com")
    end
  end

  describe ".reset!" do
    it "reverts to defaults" do
      BrandConfig.configure(brand_name: "Custom")
      BrandConfig.reset!

      expect(BrandConfig.brand_name).to eq("Scanner")
    end
  end
end
