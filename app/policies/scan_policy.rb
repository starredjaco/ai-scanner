# frozen_string_literal: true

class ScanPolicy < TenantScopedPolicy
  def rerun?
    true
  end

  def stats?
    true
  end

  def batch_rerun?
    true
  end

  def batch_destroy?
    true
  end
end
