module ProbeSourceRegistry
  class << self
    def register(source_class)
      sources << source_class unless sources.include?(source_class)
    end

    def sources
      @sources ||= []
    end

    def reset!
      @sources = []
    end
  end
end
