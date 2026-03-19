module BrandConfig
  DEFAULTS = {
    brand_name:  "Scanner",
    logo_path:   nil,
    font_family: "system-ui, sans-serif",
    powered_by:  nil,
    host_url:    nil
  }.freeze

  class << self
    def brand_name  = config[:brand_name]
    def logo_path   = config[:logo_path]
    def font_family = config[:font_family]
    def powered_by  = config[:powered_by]
    def host_url    = config[:host_url]

    def configure(overrides = {})
      @config = DEFAULTS.merge(overrides)
    end

    def reset!
      @config = nil
    end

    private

    def config
      @config ||= DEFAULTS.dup
    end
  end
end
