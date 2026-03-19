# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    # Use turbo_rails/frame layout for Turbo Frame requests (skips sidebar/header rendering)
    # Use full admin layout for direct page visits (bookmarks, refresh, initial load)
    layout -> { turbo_frame_request? ? "turbo_rails/frame" : "admin" }

    # Pundit authorization verification - ensures every action is authorized
    # NOTE: We intentionally do NOT use verify_policy_scoped globally because:
    # - ActsAsTenant handles scoping for most models automatically
    # - Only UsersController needs policy_scope (it adds its own verification)
    after_action :verify_authorized

    helper_method :skip_sidebar?, :sidebar_sections_for_action, :page_title

    before_action :set_page_title

    private

    # Disable sidebar for all migrated admin pages
    def skip_sidebar?
      @skip_sidebar.nil? ? true : @skip_sidebar
    end

    # Empty sidebar sections (no AA sidebar)
    def sidebar_sections_for_action
      @sidebar_sections || []
    end

    # Page title accessor
    def page_title
      @page_title || controller_name.titleize
    end

    # Override in subclasses to set page title
    def set_page_title
      @page_title ||= controller_name.titleize
    end
  end
end
