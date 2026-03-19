# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Company, type: :model do
  describe 'validations' do
    subject { build(:company) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_presence_of(:tier) }
  end

  describe 'tier enum' do
    it 'defines the correct tier values' do
      expect(Company.tiers).to eq({
        'tier_1' => 0,
        'tier_2' => 1,
        'tier_3' => 2,
        'tier_4' => 3
      })
    end

    it 'defaults to tier_1' do
      company = Company.new(name: 'Test', slug: 'test')
      expect(company.tier).to eq('tier_1')
      expect(company.tier_1?).to be true
    end

    it 'can be set to each tier' do
      %i[tier_1 tier_2 tier_3 tier_4].each do |tier|
        company = build(:company, tier: tier)
        expect(company.send("#{tier}?")).to be true
      end
    end
  end

  describe 'access methods' do
    let(:company) { create(:company) }

    it 'responds to scan_allowed?' do
      expect(company).to respond_to(:scan_allowed?)
    end

    it 'responds to scans_remaining' do
      expect(company).to respond_to(:scans_remaining)
    end

    it 'responds to can_add_user?' do
      expect(company).to respond_to(:can_add_user?)
    end

    it 'responds to users_remaining' do
      expect(company).to respond_to(:users_remaining)
    end

    it 'responds to can_use?' do
      expect(company).to respond_to(:can_use?)
    end
  end

  describe '#increment_scan_count!' do
    let(:company) { create(:company, weekly_scan_count: 0, total_scans_count: 5, week_start_date: Date.current.beginning_of_week) }

    it 'increments weekly_scan_count atomically' do
      expect { company.increment_scan_count! }.to change { company.reload.weekly_scan_count }.from(0).to(1)
    end

    it 'increments total_scans_count atomically' do
      expect { company.increment_scan_count! }.to change { company.reload.total_scans_count }.from(5).to(6)
    end
  end

  describe '#decrement_scan_count!' do
    let(:company) { create(:company, weekly_scan_count: 3, total_scans_count: 10, week_start_date: Date.current.beginning_of_week) }

    it 'decrements weekly_scan_count atomically' do
      expect { company.decrement_scan_count! }.to change { company.reload.weekly_scan_count }.from(3).to(2)
    end

    it 'decrements total_scans_count atomically' do
      expect { company.decrement_scan_count! }.to change { company.reload.total_scans_count }.from(10).to(9)
    end

    it 'does not go below zero for weekly_scan_count' do
      company.update_columns(weekly_scan_count: 0)
      company.decrement_scan_count!
      expect(company.reload.weekly_scan_count).to eq(0)
    end

    it 'does not go below zero for total_scans_count' do
      company.update_columns(total_scans_count: 0)
      company.decrement_scan_count!
      expect(company.reload.total_scans_count).to eq(0)
    end
  end

  describe 'slug generation' do
    it 'generates slug from name if not provided' do
      company = Company.new(name: 'My Test Company')
      company.valid?
      expect(company.slug).to eq('my-test-company')
    end

    it 'does not override provided slug' do
      company = Company.new(name: 'My Test Company', slug: 'custom-slug')
      company.valid?
      expect(company.slug).to eq('custom-slug')
    end

    it 'handles duplicate slugs by appending number' do
      create(:company, slug: 'test-company')
      company = Company.new(name: 'Test Company')
      company.valid?
      expect(company.slug).to eq('test-company-1')
    end
  end

  describe 'ransackable_attributes' do
    it 'includes expected attributes for search' do
      expected = %w[id name slug external_id tier weekly_scan_count total_scans_count created_at updated_at]
      expect(Company.ransackable_attributes).to match_array(expected)
    end
  end
end
