# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SettingsPolicy do
  let(:company) { create(:company) }
  let(:super_admin) { create(:user, :super_admin, company: company) }
  let(:regular_user) { create(:user, company: company) }

  # SettingsPolicy uses a symbol :settings as the record
  let(:settings) { :settings }

  describe '#show?' do
    it 'allows super admin to view settings' do
      expect(described_class.new(super_admin, settings).show?).to be true
    end

    it 'denies regular user from viewing settings' do
      expect(described_class.new(regular_user, settings).show?).to be false
    end
  end

  describe '#update?' do
    it 'allows super admin to update settings' do
      expect(described_class.new(super_admin, settings).update?).to be true
    end

    it 'denies regular user from updating settings' do
      expect(described_class.new(regular_user, settings).update?).to be false
    end
  end

  describe '#manage_super_admin_settings?' do
    it 'allows super admin to manage super admin settings' do
      expect(described_class.new(super_admin, settings).manage_super_admin_settings?).to be true
    end

    it 'denies regular user from managing super admin settings' do
      expect(described_class.new(regular_user, settings).manage_super_admin_settings?).to be false
    end

    context 'sensitive settings protection' do
      # These settings should only be visible/editable by super admins:
      # - custom_header_html

      it 'protects sensitive settings from regular users' do
        policy = described_class.new(regular_user, settings)
        expect(policy.manage_super_admin_settings?).to be false
      end

      it 'allows super admin to access sensitive settings' do
        policy = described_class.new(super_admin, settings)
        expect(policy.manage_super_admin_settings?).to be true
      end
    end
  end
end
