# frozen_string_literal: true

# Base policy for resources that are already scoped by ActsAsTenant.
#
# IMPORTANT: This policy relies on ActsAsTenant being properly configured:
# - Models using this policy MUST have `acts_as_tenant :company`
# - ApplicationController MUST call `set_current_tenant(current_user.company)`
# - Tenant context MUST be set before any database queries
#
# With ActsAsTenant active, all queries are automatically scoped to the current
# tenant (company), so Pundit permissions can be permissive - users can only
# access records within their tenant by default.
#
# WARNING: If ActsAsTenant is bypassed (e.g., via `ActsAsTenant.without_tenant`),
# these permissive defaults could expose data across tenants. Only bypass tenant
# scoping in super_admin contexts with explicit authorization checks.
#
# Used by: Target, Scan, Report, EnvironmentVariable, OutputServer, Metadatum
#
class TenantScopedPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # ActsAsTenant automatically scopes queries to current tenant.
      # No additional filtering needed - just return all records.
      scope.all
    end
  end
end
