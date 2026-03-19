# frozen_string_literal: true

class ProbePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    return true if super_admin?
    probe_access&.can_access?(record) || false
  end

  # Probes are read-only for regular users
  # Tier-based access is enforced via ProbeAccess service

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Super admins can see all probes
      return scope.all if super_admin?

      company = ActsAsTenant.current_tenant
      return scope.none unless company

      # Filter probes based on company access level
      Scanner.configuration.probe_access_class_constant.new(company).filter_accessible(scope)
    end
  end

  private

  def probe_access
    company = ActsAsTenant.current_tenant
    @probe_access ||= Scanner.configuration.probe_access_class_constant.new(company) if company
  end
end
