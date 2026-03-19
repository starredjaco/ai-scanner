require "rails_helper"

RSpec.describe Scanner::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets probe_access_class to ProbeAccess" do
      expect(config.probe_access_class).to eq("ProbeAccess")
    end

    it "sets retention_strategy_class to Retention::SimpleStrategy" do
      expect(config.retention_strategy_class).to eq("Retention::SimpleStrategy")
    end

    it "sets auth_providers to empty array" do
      expect(config.auth_providers).to eq([])
    end

    it "sets portal_export_enabled to false" do
      expect(config.portal_export_enabled).to be false
    end

    it "initializes hooks as empty hash with default arrays" do
      expect(config.hooks).to be_a(Hash)
      expect(config.hooks[:any_event]).to eq([])
    end

    it "sets validation_probe to a community garak probe" do
      expect(config.validation_probe).to eq("dan.Dan_11_0")
    end
  end

  describe "#probe_access_class_constant" do
    it "constantizes the probe_access_class string" do
      stub_const("ProbeAccess", Class.new)
      expect(config.probe_access_class_constant).to eq(ProbeAccess)
    end
  end

  describe "#retention_strategy_class_constant" do
    it "constantizes the retention_strategy_class string" do
      stub_const("Retention::SimpleStrategy", Class.new)
      expect(config.retention_strategy_class_constant).to eq(Retention::SimpleStrategy)
    end
  end
end

RSpec.describe Scanner do
  before do
    # Reset configuration between tests
    Scanner.instance_variable_set(:@configuration, nil)
  end

  after do
    Scanner.instance_variable_set(:@configuration, nil)
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(Scanner.configuration).to be_a(Scanner::Configuration)
    end

    it "memoizes the configuration" do
      expect(Scanner.configuration).to be(Scanner.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      Scanner.configure do |config|
        config.probe_access_class = "CustomProbeAccess"
        config.portal_export_enabled = true
      end

      expect(Scanner.configuration.probe_access_class).to eq("CustomProbeAccess")
      expect(Scanner.configuration.portal_export_enabled).to be true
    end
  end

  describe ".register_hook" do
    it "registers a block hook" do
      called = false
      Scanner.register_hook(:test_event) { called = true }
      Scanner.run_hooks(:test_event)

      expect(called).to be true
    end

    it "registers a callable hook" do
      callable = ->(ctx) { ctx[:result] = "called" }
      Scanner.register_hook(:test_event, callable)

      expect(Scanner.configuration.hooks[:test_event]).to include(callable)
    end
  end

  describe ".run_hooks" do
    it "calls all registered hooks for the event with context" do
      results = []
      Scanner.register_hook(:test_event) { |ctx| results << "hook1:#{ctx[:data]}" }
      Scanner.register_hook(:test_event) { |ctx| results << "hook2:#{ctx[:data]}" }

      Scanner.run_hooks(:test_event, { data: "test" })

      expect(results).to eq([ "hook1:test", "hook2:test" ])
    end

    it "does nothing for events with no hooks" do
      expect { Scanner.run_hooks(:nonexistent_event) }.not_to raise_error
    end

    it "isolates hook errors and continues running remaining hooks" do
      results = []
      Scanner.register_hook(:test_event) { |_ctx| results << "hook1" }
      Scanner.register_hook(:test_event) { |_ctx| raise "hook2 failed" }
      Scanner.register_hook(:test_event) { |_ctx| results << "hook3" }

      expect(Rails.logger).to receive(:error).with(/Hook error for test_event/)
      expect { Scanner.run_hooks(:test_event) }.not_to raise_error
      expect(results).to eq(%w[hook1 hook3])
    end
  end
end
