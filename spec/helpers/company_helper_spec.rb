# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompanyHelper, type: :helper do
  describe "#tier_display_name" do
    it "formats 'tier_1' as 'Tier 1'" do
      expect(helper.tier_display_name("tier_1")).to eq("Tier 1")
    end

    it "formats 'tier_2' as 'Tier 2'" do
      expect(helper.tier_display_name("tier_2")).to eq("Tier 2")
    end

    it "formats 'tier_3' as 'Tier 3'" do
      expect(helper.tier_display_name("tier_3")).to eq("Tier 3")
    end

    it "formats 'tier_4' as 'Tier 4'" do
      expect(helper.tier_display_name("tier_4")).to eq("Tier 4")
    end

    it "handles symbols" do
      expect(helper.tier_display_name(:tier_2)).to eq("Tier 2")
    end
  end

  describe "#tier_badge_color" do
    it "returns :gray for tier_1" do
      expect(helper.tier_badge_color("tier_1")).to eq(:gray)
    end

    it "returns :blue for tier_2" do
      expect(helper.tier_badge_color("tier_2")).to eq(:blue)
    end

    it "returns :indigo for tier_3" do
      expect(helper.tier_badge_color("tier_3")).to eq(:indigo)
    end

    it "returns :purple for tier_4" do
      expect(helper.tier_badge_color("tier_4")).to eq(:purple)
    end

    it "returns :gray for unknown tier" do
      expect(helper.tier_badge_color("unknown")).to eq(:gray)
    end

    it "handles symbols" do
      expect(helper.tier_badge_color(:tier_4)).to eq(:purple)
    end
  end

  describe "#next_quota_reset_day" do
    it "returns 'Monday' (next reset day)" do
      # Quota always resets on Monday
      travel_to Time.zone.local(2026, 1, 8) do # Thursday
        expect(helper.next_quota_reset_day).to eq("Monday")
      end
    end

    it "returns 'Monday' even when today is Sunday" do
      travel_to Time.zone.local(2026, 1, 11) do # Sunday
        expect(helper.next_quota_reset_day).to eq("Monday")
      end
    end

    it "returns next Monday when today is Monday" do
      travel_to Time.zone.local(2026, 1, 12) do # Monday
        # next_occurring(:monday) should return the NEXT Monday
        expect(helper.next_quota_reset_day).to eq("Monday")
      end
    end
  end

  describe "#progress_bar_color_class" do
    it "returns green class for :green" do
      expect(helper.progress_bar_color_class(:green)).to eq("bg-green-500")
    end

    it "returns yellow class for :yellow" do
      expect(helper.progress_bar_color_class(:yellow)).to eq("bg-yellow-500")
    end

    it "returns red class for :red" do
      expect(helper.progress_bar_color_class(:red)).to eq("bg-red-500")
    end

    it "returns purple class for :purple" do
      expect(helper.progress_bar_color_class(:purple)).to eq("bg-purple-500")
    end

    it "returns gray class for unknown color" do
      expect(helper.progress_bar_color_class(:unknown)).to eq("bg-gray-500")
    end
  end

  describe "#tier_css_class" do
    it "returns correct classes for tier_1" do
      expect(helper.tier_css_class("tier_1")).to include("bg-gray-100")
      expect(helper.tier_css_class("tier_1")).to include("text-gray-800")
    end

    it "returns correct classes for tier_2" do
      expect(helper.tier_css_class("tier_2")).to include("bg-blue-100")
      expect(helper.tier_css_class("tier_2")).to include("text-blue-800")
    end

    it "returns correct classes for tier_3" do
      expect(helper.tier_css_class("tier_3")).to include("bg-indigo-100")
      expect(helper.tier_css_class("tier_3")).to include("text-indigo-800")
    end

    it "returns correct classes for tier_4" do
      expect(helper.tier_css_class("tier_4")).to include("bg-purple-100")
      expect(helper.tier_css_class("tier_4")).to include("text-purple-800")
    end

    it "handles symbols" do
      expect(helper.tier_css_class(:tier_2)).to include("bg-blue-100")
    end

    it "returns tier_1 classes for unknown tier" do
      expect(helper.tier_css_class("unknown")).to include("bg-gray-100")
    end

    it "includes dark mode classes" do
      expect(helper.tier_css_class("tier_4")).to include("dark:bg-purple-900")
      expect(helper.tier_css_class("tier_4")).to include("dark:text-purple-300")
    end
  end

  describe "#tier_badge" do
    let(:company) { create(:company, tier: :tier_2) }

    it "returns a span element" do
      result = helper.tier_badge(company)
      expect(result).to match(/<span.*>.*<\/span>/)
    end

    it "contains the tier display name" do
      result = helper.tier_badge(company)
      expect(result).to include("Tier 2")
    end

    it "includes CSS classes for styling" do
      result = helper.tier_badge(company)
      expect(result).to include("px-2")
      expect(result).to include("text-xs")
      expect(result).to include("rounded")
    end

    it "includes tier-specific color classes" do
      result = helper.tier_badge(company)
      expect(result).to include("bg-blue-100")
    end

    context "with different tiers" do
      it "renders tier_1 badge correctly" do
        company = create(:company, tier: :tier_1)
        result = helper.tier_badge(company)
        expect(result).to include("Tier 1")
        expect(result).to include("bg-gray-100")
      end

      it "renders tier_4 badge correctly" do
        company = create(:company, tier: :tier_4)
        result = helper.tier_badge(company)
        expect(result).to include("Tier 4")
        expect(result).to include("bg-purple-100")
      end
    end
  end

  describe "#company_link_with_tier" do
    let(:company) { create(:company, tier: :tier_3) }

    before do
      # Stub routes for helper
      allow(helper).to receive(:company_path).with(company).and_return("/companies/#{company.id}")
    end

    it "returns a div container" do
      result = helper.company_link_with_tier(company)
      expect(result).to match(/<div.*>.*<\/div>/m)
    end

    it "includes a link to the company" do
      result = helper.company_link_with_tier(company)
      expect(result).to include(company.name)
      expect(result).to include("href=\"/companies/#{company.id}\"")
    end

    it "includes the tier badge" do
      result = helper.company_link_with_tier(company)
      expect(result).to include("Tier 3")
      expect(result).to include("bg-indigo-100")
    end

    it "includes flex layout classes" do
      result = helper.company_link_with_tier(company)
      expect(result).to include("flex")
      expect(result).to include("items-center")
      expect(result).to include("gap-2")
    end

    it "includes link styling" do
      result = helper.company_link_with_tier(company)
      expect(result).to include("text-primary")
      expect(result).to include("hover:underline")
      expect(result).to include("dark:text-primary-400")
    end
  end
end
