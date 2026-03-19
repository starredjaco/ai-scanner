# frozen_string_literal: true

class EnvironmentVariablePolicy < TenantScopedPolicy
  def batch_destroy?
    true
  end
end
