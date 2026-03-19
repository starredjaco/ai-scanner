module ApplicationHelper
  include ScoresHelper

  def format_created_date(datetime)
    datetime.present? ? datetime.strftime("%Y-%m-%d") : nil
  end

  def format_count(count)
    if count >= 1000
      number_to_human(count,
        precision: 1,
        significant: false,
        strip_insignificant_zeros: false,
        format: "%n%u",
        units: { thousand: "k", million: "M", billion: "B" }
      )
    else
      number_with_delimiter(count)
    end
  end

  def formatted_scope_count(count)
    formatted = format_count(count)
    original = number_with_delimiter(count)
    "<span class=\"scopes-count\" title=\"#{original}\">#{formatted}</span>".html_safe
  end

  def scope_with_formatted_count(label, count)
    formatted = format_count(count)
    original = number_with_delimiter(count)
    raw("#{label} <span class=\"scopes-count\" title=\"#{original}\">#{formatted}</span>")
  end

  def mask_sensitive_value(value, show_chars = 4)
    return "" if value.blank?

    if value.length <= show_chars * 2
      # If the value is too short, show some asterisks
      "*" * [ value.length, 8 ].min
    else
      # Show first 4 and last 4 characters with asterisks in between
      first_part = value[0, show_chars]
      last_part = value[-show_chars, show_chars]
      asterisk_count = [ value.length - (show_chars * 2), 4 ].max
      "#{first_part}#{'*' * asterisk_count}#{last_part}"
    end
  end

  def mask_access_token(token)
    mask_sensitive_value(token)
  end

  def mask_api_key(api_key)
    mask_sensitive_value(api_key)
  end

  # Get CSS text color class for Attack Success Rate (ASR) based on threshold ranges
  # Lower ASR = better security (lighter colors), Higher ASR = worse security (warmer/red colors)
  #
  # Delegates to ScoresHelper#score_color_class with bold: false
  def asr_color_class(asr_percentage)
    score_color_class(asr_percentage, bold: false, nil_class: "text-contentSecondary")
  end
end
