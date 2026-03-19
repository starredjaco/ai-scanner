# frozen_string_literal: true

require "rails_helper"

RSpec.describe OssDefaults do
  let(:test_class) do
    Class.new do
      include OssDefaults
    end
  end

  let(:instance) { test_class.new }

  describe "#scan_allowed?" do
    it "always returns true" do
      expect(instance.scan_allowed?).to be true
    end
  end

  describe "#scans_remaining" do
    it "returns infinity" do
      expect(instance.scans_remaining).to eq(Float::INFINITY)
    end
  end

  describe "#can_add_user?" do
    it "always returns true" do
      expect(instance.can_add_user?).to be true
    end
  end

  describe "#users_remaining" do
    it "returns infinity" do
      expect(instance.users_remaining).to eq(Float::INFINITY)
    end
  end

  describe "#can_use?" do
    it "returns true for any feature" do
      expect(instance.can_use?(:scheduled_scans)).to be true
      expect(instance.can_use?(:rbac)).to be true
      expect(instance.can_use?(:unknown_feature)).to be true
    end
  end

  describe "#unlimited_scans?" do
    it "always returns true" do
      expect(instance.unlimited_scans?).to be true
    end
  end

  describe "#scans_per_week_limit" do
    it "returns nil" do
      expect(instance.scans_per_week_limit).to be_nil
    end
  end
end
