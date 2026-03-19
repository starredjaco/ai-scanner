# frozen_string_literal: true

class CompanyPolicy < ApplicationPolicy
  def index?
    super_admin?
  end

  def show?
    super_admin? || record == user.current_company
  end

  def create?
    super_admin?
  end

  def update?
    super_admin?
  end

  def destroy?
    super_admin?
  end

  # UI visibility helpers

  def menu_visible?
    super_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if super_admin?
        scope.all
      else
        scope.where(id: user.current_company_id)
      end
    end
  end
end
