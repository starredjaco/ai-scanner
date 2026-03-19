module Scanner
  class Configuration
    # Service class names (strings, resolved lazily)
    attr_accessor :probe_access_class
    attr_accessor :retention_strategy_class

    # Feature flags the engine can flip
    attr_accessor :auth_providers
    attr_accessor :portal_export_enabled
    attr_accessor :validation_probe

    # Lifecycle hook registries (arrays of callables)
    attr_reader :hooks

    def initialize
      @probe_access_class       = "ProbeAccess"
      @retention_strategy_class = "Retention::SimpleStrategy"
      @auth_providers           = []
      @portal_export_enabled    = false
      @validation_probe         = "dan.Dan_11_0"
      @hooks                    = Hash.new { |h, k| h[k] = [] }
    end

    def probe_access_class_constant
      probe_access_class.constantize
    end

    def retention_strategy_class_constant
      retention_strategy_class.constantize
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def register_hook(event, callable = nil, &block)
      configuration.hooks[event] << (callable || block)
    end

    def run_hooks(event, context = {})
      configuration.hooks[event].each do |hook|
        hook.call(context)
      rescue StandardError => e
        Rails.logger.error "[Scanner] Hook error for #{event}: #{e.class}: #{e.message}"
        Rails.logger.debug { e.backtrace.first(10).join("\n") }
      end
    end
  end
end
