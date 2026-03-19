# frozen_string_literal: true

class SettingsPolicy < ApplicationPolicy
  def show?
    super_admin?
  end

  def update?
    super_admin?
  end

  # Can this user manage super admin-only settings?
  # (e.g., custom_header_html)
  def manage_super_admin_settings?
    super_admin?
  end
end
