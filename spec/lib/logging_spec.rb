require "rails_helper"
require "logging"

RSpec.describe Logging do
  describe ".with" do
    before do
      Thread.current[:fs_log_context] = {}
    end

    after do
      Thread.current[:fs_log_context] = {}
    end

    it "sets context for the duration of the block" do
      expect(Logging.context).to eq({})

      Logging.with(user_id: 123, action: "test") do
        expect(Logging.context).to eq(user_id: 123, action: "test")
      end

      expect(Logging.context).to eq({})
    end

    it "restores original context after block execution" do
      Logging.with(original: "value") do
        expect(Logging.context).to eq(original: "value")

        Logging.with(nested: "context") do
          expect(Logging.context).to include(original: "value", nested: "context")
        end

        expect(Logging.context).to eq(original: "value")
      end

      expect(Logging.context).to eq({})
    end

    it "restores context even when an exception is raised" do
      Logging.with(before: "exception") do
        expect(Logging.context).to eq(before: "exception")
      end

      expect do
        Logging.with(during: "exception") do
          expect(Logging.context).to eq(during: "exception")
          raise StandardError, "Test error"
        end
      end.to raise_error(StandardError, "Test error")

      expect(Logging.context).to eq({})
    end

    it "handles nested contexts correctly" do
      Logging.with(level1: "a") do
        expect(Logging.context).to eq(level1: "a")

        Logging.with(level2: "b") do
          expect(Logging.context).to eq(level1: "a", level2: "b")

          Logging.with(level3: "c") do
            expect(Logging.context).to eq(level1: "a", level2: "b", level3: "c")
          end

          expect(Logging.context).to eq(level1: "a", level2: "b")
        end

        expect(Logging.context).to eq(level1: "a")
      end

      expect(Logging.context).to eq({})
    end

    it "merges context without modifying the original" do
      original_context = { original: "value" }
      Thread.current[:fs_log_context] = original_context

      Logging.with(added: "value") do
        expect(Logging.context).to include(original: "value", added: "value")
      end

      # The context is restored after the block, but the original might be modified in place
      # This is the current behavior of the implementation
      expect(Logging.context).to eq(original: "value")
    end

    it "handles empty hash gracefully" do
      Logging.with({}) do
        expect(Logging.context).to eq({})
      end

      expect(Logging.context).to eq({})
    end

    it "allows context values to be overwritten in nested blocks" do
      Logging.with(key: "value1") do
        expect(Logging.context[:key]).to eq("value1")

        Logging.with(key: "value2") do
          expect(Logging.context[:key]).to eq("value2")
        end

        expect(Logging.context[:key]).to eq("value1")
      end
    end
  end

  describe ".context" do
    before do
      Thread.current[:fs_log_context] = nil
    end

    it "returns an empty hash when no context is set" do
      expect(Logging.context).to eq({})
    end

    it "returns the current thread's context" do
      Thread.current[:fs_log_context] = { test: "value" }
      expect(Logging.context).to eq(test: "value")
    end

    it "is thread-safe" do
      results = []
      threads = []

      3.times do |i|
        threads << Thread.new do
          Logging.with(thread_id: i) do
            sleep(0.01 * rand) # Random small delay
            results << Logging.context[:thread_id]
          end
        end
      end

      threads.each(&:join)
      expect(results.sort).to eq([ 0, 1, 2 ])
    end
  end

  describe Logging::JSONFormatter do
    let(:formatter) { described_class.new }
    let(:time) { Time.now }

    before do
      Thread.current[:fs_log_context] = {}
    end

    it "formats log messages as JSON" do
      result = formatter.call("INFO", time, "TestApp", "Test message")
      parsed = JSON.parse(result)

      expect(parsed["level"]).to eq("INFO")
      expect(parsed["progname"]).to eq("TestApp")
      expect(parsed["message"]).to eq("Test message")
    end

    it "includes context in the output" do
      Thread.current[:fs_log_context] = { user_id: 123, action: "test" }

      result = formatter.call("INFO", time, "TestApp", "Test message")
      parsed = JSON.parse(result)

      expect(parsed["user_id"]).to eq(123)
      expect(parsed["action"]).to eq("test")
    end

    it "handles nil values gracefully" do
      result = formatter.call(nil, nil, nil, nil)
      parsed = JSON.parse(result)

      expect(parsed["level"]).to eq("")
      expect(parsed["message"]).to eq("")
      expect(parsed).not_to have_key("progname")
    end

    it "removes nil values from output" do
      result = formatter.call("INFO", time, nil, "Test message")
      parsed = JSON.parse(result)

      expect(parsed).not_to have_key("progname")
      expect(parsed["level"]).to eq("INFO")
      expect(parsed["message"]).to eq("Test message")
    end

    it "ends output with a newline" do
      result = formatter.call("INFO", time, "TestApp", "Test message")
      expect(result).to end_with("\r\n")
    end

    it "preserves complex context structures" do
      Thread.current[:fs_log_context] = {
        user: { id: 123, name: "Test User" },
        metadata: [ "tag1", "tag2" ],
        count: 42
      }

      result = formatter.call("INFO", time, "TestApp", "Test message")
      parsed = JSON.parse(result)

      expect(parsed["user"]).to eq("id" => 123, "name" => "Test User")
      expect(parsed["metadata"]).to eq([ "tag1", "tag2" ])
      expect(parsed["count"]).to eq(42)
    end

    it "handles special characters in messages" do
      message = 'Test "quoted" message with \n newline'
      result = formatter.call("INFO", time, "TestApp", message)
      parsed = JSON.parse(result)

      expect(parsed["message"]).to eq(message)
    end

    it "maintains consistent key order" do
      Thread.current[:fs_log_context] = { z_key: "value", a_key: "value" }

      result = formatter.call("INFO", time, "TestApp", "Test")
      parsed = JSON.parse(result)

      # Base keys should come first
      keys = parsed.keys
      expect(keys[0..2]).to eq([ "level", "progname", "message" ])
    end
  end
end
