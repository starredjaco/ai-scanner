# frozen_string_literal: true

class ImpersonationPolicy < ApplicationPolicy
  # record is the target user to impersonate
  def create?
    super_admin? && !record.super_admin? && record != user
  end

  def destroy?
    true # Can always stop impersonating
  end
end
