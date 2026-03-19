# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Method
  include ApplicationHelper
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  set_current_tenant_through_filter
  around_action :set_time_zone

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Skip browser check for internal service requests (e.g., Cypress tests via scanner-preview)
  allow_browser versions: :modern, block: -> {
    # Allow requests from internal service hostnames (scanner-preview, scanner, localhost)
    internal_hosts = %w[scanner scanner-preview localhost 127.0.0.1]
    !request.host.in?(internal_hosts)
  }
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_tenant
  before_action :auto_set_user_time_zone
  before_action :set_monitoring_user_context

  helper_method :true_current_user, :impersonating?, :current_company, :probe_access

  # Returns the effective user (impersonated user if impersonating, otherwise actual user)
  def current_user
    @current_user ||= if impersonating?
      User.find_by(id: session[:impersonated_user_id])
    else
      super
    end
  end

  # The actual logged-in user (super admin during impersonation)
  def true_current_user
    @true_current_user ||= if session[:admin_user_id]
      User.find_by(id: session[:admin_user_id])
    else
      warden.authenticate(scope: :user)
    end
  end

  # Check if currently impersonating another user
  def impersonating?
    session[:admin_user_id].present? && session[:impersonated_user_id].present?
  end

  # Current company (tenant) for tier-based access
  def current_company
    ActsAsTenant.current_tenant
  end

  # ProbeAccess service for probe filtering (configurable via Scanner.configuration)
  def probe_access
    @probe_access ||= Scanner.configuration.probe_access_class_constant.new(current_company) if current_company
  end

  def authenticate_user!
    redirect_to new_user_session_path unless current_user
  end

  private

  def set_tenant
    company = current_user&.current_company || current_user&.companies&.first
    set_current_tenant(company)

    # Auto-set current_company if not set but user has companies
    if current_user && current_user.current_company_id.nil? && company
      current_user.update_column(:current_company_id, company.id)
    end
  end

  def auto_set_user_time_zone
    return unless current_user && current_user.time_zone.blank?
    tz = cookies[:browser_timezone]
    return unless tz.present?

    # Browser sends IANA timezone (e.g., "America/Los_Angeles")
    # We need to map it to ActiveSupport friendly name (e.g., "Pacific Time (US & Canada)")
    zone = ActiveSupport::TimeZone.all.find { |z| z.tzinfo.name == tz }
    if zone
      current_user.update_column(:time_zone, zone.name)
    end
  end

  def set_time_zone(&block)
    Time.use_zone(current_time_zone, &block)
  end

  def current_time_zone
    if current_user&.time_zone.present?
      return current_user.time_zone
    end
    "UTC"
  end

  def user_not_authorized
    flash[:alert] = "Not authorized."
    redirect_back(fallback_location: root_path)
  end

  def set_monitoring_user_context
    MonitoringService.set_user(current_user) if current_user
  end
end
