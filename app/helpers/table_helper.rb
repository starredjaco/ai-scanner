# frozen_string_literal: true

module TableHelper
  # Badge color classes for different states
  BADGE_COLORS = {
    running: "bg-zinc-800 text-zinc-400 dark:bg-zinc-800 dark:text-zinc-400",
    completed: "bg-lime-950 text-lime-400 dark:bg-lime-950 dark:text-lime-400",
    failed: "bg-red-950 text-red-400 dark:bg-red-950 dark:text-red-400"
  }.freeze

  # Status indicator colors (dots)
  STATUS_INDICATOR_COLORS = {
    success: "bg-lime-400",
    good: "bg-lime-400",
    error: "bg-red-400",
    bad: "bg-red-400",
    validating: "bg-zinc-500 animate-pulse",
    pending: "bg-zinc-500",
    info: "bg-zinc-500",
    warning: "bg-zinc-500",
    neutral: "bg-zinc-500"
  }.freeze

  # Render a badge with specified color
  def table_badge(text, color: :running, extra_classes: "")
    color_classes = BADGE_COLORS[color.to_sym] || BADGE_COLORS[:running]
    content_tag(:span, text,
                class: "inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-medium #{color_classes} #{extra_classes}")
  end

  # Render a status indicator dot
  def table_status_indicator(status, extra_classes: "")
    color_class = STATUS_INDICATOR_COLORS[status.to_sym] || STATUS_INDICATOR_COLORS[:pending]
    content_tag(:div, nil,
                class: "w-3 h-3 rounded-full #{color_class} #{extra_classes}")
  end

  # Get cell value from item using column config
  def table_cell_value(item, column)
    key = column[:key]
    return nil unless key

    if column[:value].is_a?(Proc)
      column[:value].call(item)
    elsif item.respond_to?(key)
      item.send(key)
    else
      nil
    end
  end

  # Get link path for a cell
  def table_cell_link_path(item, column)
    if column[:link_path].is_a?(Proc)
      column[:link_path].call(item)
    elsif column[:link_path].is_a?(Symbol)
      send(column[:link_path], item)
    else
      column[:link_path]
    end
  end

  # Get badge color for a cell
  def table_cell_badge_color(item, column)
    if column[:badge_color].is_a?(Proc)
      column[:badge_color].call(item)
    else
      column[:badge_color] || :gray
    end
  end

  # Format date for display
  def table_format_date(value, format: :short)
    return nil unless value

    case format
    when :short
      value.strftime("%Y-%m-%d")
    when :long
      value.strftime("%B %d, %Y")
    when :datetime
      value.strftime("%Y-%m-%d %H:%M")
    when :full
      value.strftime("%B %d, %Y at %I:%M %p")
    else
      value.strftime(format.to_s)
    end
  end

  # Determine cell type and render appropriate partial
  def table_render_cell(item, column, ransack: nil)
    type = column[:type] || :text
    partial_path = "shared/table/cells/#{type}"

    render partial: partial_path, locals: {
      item: item,
      column: column,
      value: table_cell_value(item, column),
      ransack: ransack
    }
  end

  # Render sort link for header
  def table_sort_header(column, ransack: nil)
    label = column[:label] || column[:key].to_s.titleize

    if column[:sortable] && ransack
      sort_key = column[:sort_key] || column[:key]
      sort_link(ransack, sort_key, label,
                class: "text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 group inline-flex items-center gap-1")
    else
      content_tag(:span, label, class: "text-gray-500 dark:text-gray-400")
    end
  end

  # Success rate color based on percentage (for probes)
  def success_rate_color_class(rate)
    return "text-gray-500 dark:text-gray-400" if rate.nil?

    case rate
    when 0...25
      "text-red-600 dark:text-red-400"
    when 25...50
      "text-orange-600 dark:text-orange-400"
    when 50...75
      "text-yellow-600 dark:text-yellow-400"
    else
      "text-green-600 dark:text-green-400"
    end
  end
end
