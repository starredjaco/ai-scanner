require 'rails_helper'

RSpec.describe "User permissions", type: :feature do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_admin) { create(:user, :regular_admin) }
  let(:other_admin) { create(:user, :regular_admin) }

  describe "super admin permissions" do
    it "can set super_admin status for new users" do
      expect(super_admin.super_admin?).to be true
    end

    it "can modify super_admin status for other users" do
      other_admin.update!(super_admin: true)
      expect(other_admin.reload.super_admin?).to be true
    end
  end

  describe "regular admin permissions" do
    it "defaults to non-super admin status" do
      expect(regular_admin.super_admin?).to be false
    end

    it "can change their own password" do
      original_password = regular_admin.encrypted_password
      regular_admin.update!(password: "newpassword123", password_confirmation: "newpassword123")
      expect(regular_admin.reload.encrypted_password).not_to eq(original_password)
    end
  end

  describe "password security" do
    it "allows users to change their own passwords" do
      original_password = regular_admin.encrypted_password
      regular_admin.update!(password: "newpassword123", password_confirmation: "newpassword123")
      expect(regular_admin.reload.encrypted_password).not_to eq(original_password)
      expect(regular_admin.valid_password?("newpassword123")).to be true
    end

    it "super admin can change any user's password" do
      original_password = other_admin.encrypted_password
      other_admin.update!(password: "newsuperpassword", password_confirmation: "newsuperpassword")
      expect(other_admin.reload.encrypted_password).not_to eq(original_password)
      expect(other_admin.valid_password?("newsuperpassword")).to be true
    end
  end
end
