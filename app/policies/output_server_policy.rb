# frozen_string_literal: true

class OutputServerPolicy < TenantScopedPolicy
  def index?
    can_use_integrations?
  end

  def show?
    can_use_integrations?
  end

  def create?
    can_use_integrations?
  end

  def new?
    can_use_integrations?
  end

  def update?
    can_use_integrations?
  end

  def edit?
    can_use_integrations?
  end

  def destroy?
    can_use_integrations?
  end

  def test?
    can_use_integrations?
  end

  def menu_visible?
    can_use_integrations?
  end

  private

  def can_use_integrations?
    user.current_company&.can_use?(:integrations)
  end
end
