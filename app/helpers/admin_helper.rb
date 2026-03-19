# frozen_string_literal: true

module AdminHelper
  # Status tag helper for admin views
  # Usage: status_tag("Active", :ok) or status_tag("Pending")
  def status_tag(text, status = nil)
    # Map status to CSS classes
    status_classes = case status
    when :ok, :yes, "ok", "yes", true
      "bg-lime-950 text-lime-400 dark:bg-lime-950 dark:text-lime-400"
    when :warning, :warn, "warning", "warn"
      "bg-zinc-800 text-zinc-400 dark:bg-zinc-800 dark:text-zinc-400"
    when :error, :no, "error", "no", false
      "bg-red-950 text-red-400 dark:bg-red-950 dark:text-red-400"
    else
      # Auto-detect based on text content if no status provided
      case text.to_s.downcase
      when "completed", "success", "active", "yes", "ok", "enabled", "passed"
        "bg-lime-950 text-lime-400 dark:bg-lime-950 dark:text-lime-400"
      when "pending", "processing", "in_progress", "in progress", "running", "interrupted"
        "bg-zinc-800 text-zinc-400 dark:bg-zinc-800 dark:text-zinc-400"
      when "failed", "error", "no", "disabled", "deleted", "cancelled"
        "bg-red-950 text-red-400 dark:bg-red-950 dark:text-red-400"
      when "warning", "paused", "stopped"
        "bg-zinc-800 text-zinc-400 dark:bg-zinc-800 dark:text-zinc-400"
      else
        "bg-zinc-800 text-zinc-400 dark:bg-zinc-800 dark:text-zinc-400"
      end
    end

    content_tag(:span, text.to_s.humanize, class: "inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-medium #{status_classes}")
  end

  # Menu system helpers

  def current_menu
    @current_menu ||= AdminMenu.build(self)
  end

  def current_menu_item?(item)
    item.current?(controller_path, action_name) || item.url_matches?(request.path)
  end

  # Page title helpers

  def html_head_site_title
    separator = "-"
    "#{@page_title || page_title} #{separator} #{site_title}"
  end

  def site_title
    "Scanner"
  end

  def page_title
    @page_title || controller_name.titleize
  end
end
