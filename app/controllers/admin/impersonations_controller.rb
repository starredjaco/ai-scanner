# frozen_string_literal: true

module Admin
  class ImpersonationsController < Admin::BaseController
    before_action :set_target_user, only: [ :create ]

    def create
      authorize @target_user, policy_class: ImpersonationPolicy

      # Store original admin identity
      session[:admin_user_id] = true_current_user.id
      session[:impersonated_user_id] = @target_user.id

      redirect_to root_path,
        notice: "Now viewing as #{@target_user.email}"
    end

    def destroy
      skip_authorization # Always allowed - can always stop impersonating

      session.delete(:impersonated_user_id)
      session.delete(:admin_user_id)

      redirect_to users_path,
        notice: "Returned to admin session."
    end

    private

    def set_target_user
      # Bypass tenant scoping to find any user
      @target_user = ActsAsTenant.without_tenant { User.find(params[:id]) }
    end
  end
end
