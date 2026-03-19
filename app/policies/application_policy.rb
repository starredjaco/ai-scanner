# frozen_string_literal: true

# Base policy class for all authorization policies.
# Provides common helpers and default deny-all behavior.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Convenience method: check if user is a super admin
  def super_admin?
    user&.super_admin?
  end

  # Convenience method: check if record belongs to user's company
  def same_company?
    return false unless record.respond_to?(:company_id)
    record.company_id == user.current_company_id
  end

  # Default permissions - deny by default for security
  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Base scope class for policy scopes
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "Must implement #resolve in #{self.class}"
    end

    # Convenience method for scope classes
    def super_admin?
      user&.super_admin?
    end
  end
end
