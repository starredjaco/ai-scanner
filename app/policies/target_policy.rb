# frozen_string_literal: true

class TargetPolicy < TenantScopedPolicy
  def validate?
    true
  end

  def restore?
    true
  end

  def batch_validate?
    true
  end

  def batch_destroy?
    true
  end

  def auto_detect_selectors?
    true
  end
end
