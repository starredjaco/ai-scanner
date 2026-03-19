module ScoresHelper
  # Get CSS text color class for scores based on ASR threshold ranges
  # Lower score = better security (lighter colors), Higher score = worse security (warmer/red colors)
  #
  # @param score [Numeric, nil] The score/ASR percentage to get a color for
  # @param bold [Boolean] Whether to include font-semibold class (default: true)
  # @param nil_class [String] Class to return for nil values (default: "text-zinc-400 font-semibold")
  # @return [String] Tailwind CSS color class
  def score_color_class(score, bold: true, nil_class: nil)
    if score.nil?
      return nil_class || (bold ? "text-zinc-400 font-semibold" : "text-contentSecondary")
    end

    color = case score.to_f
    when 0...25
      "text-[#71717A]"
    when 25...50
      "text-[#EEF797]"
    when 50...75
      "text-[#F89D53]"
    else
      "text-[#F87171]"
    end

    bold ? "#{color} font-semibold" : color
  end

  # Get CSS background color class for scores based on ASR threshold ranges
  # Matches the color scale in score_color_class but for backgrounds
  #
  # @param score [Numeric, nil] The score/ASR percentage to get a color for
  # @return [String] Tailwind CSS background color class
  def score_bg_color_class(score)
    return "bg-zinc-800" if score.nil?

    case score.to_f
    when 0...25
      "bg-zinc-700"
    when 25...50
      "bg-yellow-900/70"
    when 50...75
      "bg-orange-900/70"
    else
      "bg-red-900/70"
    end
  end
end
