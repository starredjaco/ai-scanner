# frozen_string_literal: true

module CompanyHelper
  TIER_BADGE_COLORS = {
    tier_1: :gray,
    tier_2: :blue,
    tier_3: :indigo,
    tier_4: :purple
  }.freeze

  TIER_LABELS = {
    "tier_1" => "Tier 1",
    "tier_2" => "Tier 2",
    "tier_3" => "Tier 3",
    "tier_4" => "Tier 4"
  }.freeze

  TIER_CSS_CLASSES = {
    "tier_1" => "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300",
    "tier_2" => "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300",
    "tier_3" => "bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-300",
    "tier_4" => "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"
  }.freeze

  PROGRESS_BAR_COLORS = {
    green: "bg-green-500",
    yellow: "bg-yellow-500",
    red: "bg-red-500",
    purple: "bg-purple-500"
  }.freeze

  # Returns color for scan quota status indicator
  # @param company [Company]
  # @return [Symbol] :green, :yellow, :red, or :purple
  def scans_quota_status_color(company)
    return :purple if company.unlimited_scans?

    remaining = company.scans_remaining
    limit = company.scans_per_week_limit

    return :green if remaining > (limit * 0.5)
    return :yellow if remaining > 0
    :red
  end

  # Returns usage percentage for progress bar (0-100)
  # @param company [Company]
  # @return [Integer] 0-100
  def scans_quota_percentage(company)
    return 0 if company.unlimited_scans?

    limit = company.scans_per_week_limit
    return 0 if limit.nil? || limit.zero?

    used = company.weekly_scan_count
    [ (used.to_f / limit * 100).round, 100 ].min
  end

  # Returns human-readable tier name
  # @param tier [String, Symbol]
  # @return [String]
  def tier_display_name(tier)
    TIER_LABELS[tier.to_s] || tier.to_s.titleize
  end

  # Returns badge color for tier
  # @param tier [String, Symbol]
  # @return [Symbol]
  def tier_badge_color(tier)
    TIER_BADGE_COLORS[tier.to_sym] || :gray
  end

  # Returns the day name when quota resets (always Monday)
  # @return [String]
  def next_quota_reset_day
    Date.current.next_occurring(:monday).strftime("%A")
  end

  # Returns Tailwind CSS class for progress bar based on status color
  # @param status_color [Symbol]
  # @return [String]
  def progress_bar_color_class(status_color)
    PROGRESS_BAR_COLORS[status_color] || "bg-gray-500"
  end

  # Returns Tailwind CSS classes for tier badge styling
  # @param tier [String]
  # @return [String]
  def tier_css_class(tier)
    TIER_CSS_CLASSES[tier.to_s] || TIER_CSS_CLASSES["tier_1"]
  end

  # Renders a tier badge span element
  # @param company [Company]
  # @return [ActiveSupport::SafeBuffer]
  def tier_badge(company)
    content_tag(:span, tier_display_name(company.tier),
      class: "px-2 py-0.5 text-xs font-medium rounded #{tier_css_class(company.tier)}")
  end

  # Returns formatted weekly scan count with limit
  # @param company [Company]
  # @return [String]
  def weekly_scan_display(company)
    if company.unlimited_scans?
      "#{company.weekly_scan_count} / ∞"
    else
      "#{company.weekly_scan_count} / #{company.scans_per_week_limit}"
    end
  end

  # Renders a company link with tier badge
  # @param company [Company]
  # @return [ActiveSupport::SafeBuffer]
  def company_link_with_tier(company)
    content_tag(:div, class: "flex items-center gap-2") do
      link = link_to(company.name, company_path(company),
        class: "text-primary hover:underline dark:text-primary-400")
      safe_join([ link, tier_badge(company) ])
    end
  end
end
