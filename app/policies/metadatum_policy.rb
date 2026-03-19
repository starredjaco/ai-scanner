# frozen_string_literal: true

class MetadatumPolicy < TenantScopedPolicy
  def create?  = super_admin?
  def update?  = super_admin?
  def destroy? = super_admin?

  private

  def super_admin? = user&.super_admin?
end
