# frozen_string_literal: true

# Base controller for Mission Control Jobs dashboard.
# Inherits auth from ApplicationController but skips tenant scoping
# (jobs dashboard is global) and restricts to super admins only.
class MissionControlController < ApplicationController
  skip_before_action :set_tenant

  before_action :require_super_admin!

  private

  def require_super_admin!
    redirect_to root_path, alert: "Not authorized." unless current_user&.super_admin?
  end
end
