require "rails_helper"

RSpec.describe BrowserAutomation::PlaywrightService do
  let(:service) { described_class.instance }

  before do
    # Reset singleton state between tests
    service.instance_variable_set(:@browser_process, nil)
    service.instance_variable_set(:@browser_ready, false)
  end

  describe "#initialize" do
    it "is a Singleton" do
      expect(described_class).to include(Singleton)
    end

    it "has nil browser_process initially" do
      expect(service.browser_process).to be_nil
    end

    it "has browser_ready false initially" do
      expect(service.browser_ready).to be false
    end
  end

  describe "#screenshot" do
    let(:url) { "https://example.com" }
    let(:output_path) { "/tmp/screenshot.png" }
    let(:success_response) { { "success" => true, "path" => output_path }.to_json }

    before do
      allow(Open3).to receive(:capture3).and_return([ success_response, "", double(success?: true) ])
    end

    it "returns the output path on success" do
      result = service.screenshot(url, output_path)
      expect(result).to eq(output_path)
    end

    it "generates a screenshot path if not provided" do
      allow(service).to receive(:generate_screenshot_path).and_return("/tmp/generated.png")
      allow(Open3).to receive(:capture3).and_return([
        { "success" => true, "path" => "/tmp/generated.png" }.to_json,
        "",
        double(success?: true)
      ])

      result = service.screenshot(url)
      expect(result).to eq("/tmp/generated.png")
    end

    it "executes playwright script with correct parameters" do
      expect(Open3).to receive(:capture3).with(
        hash_including("NODE_PATH" => Rails.root.join("node_modules").to_s),
        "node",
        anything
      ).and_return([ success_response, "", double(success?: true) ])

      service.screenshot(url, output_path)
    end

    it "raises error on failure" do
      allow(Open3).to receive(:capture3).and_return([
        { "error" => "Browser crashed" }.to_json,
        "",
        double(success?: true)
      ])

      expect {
        service.screenshot(url, output_path)
      }.to raise_error("Screenshot failed: Browser crashed")
    end

    it "accepts custom options" do
      options = { width: 1024, height: 768, full_page: true }
      script_content = nil

      allow(Open3).to receive(:capture3) do |_env, _command, script_path|
        script_content = File.read(script_path)
        [ success_response, "", double(success?: true) ]
      end

      service.screenshot(url, output_path, options)

      # Verify that the options were used in the generated script
      expect(script_content).to include("width: 1024")
      expect(script_content).to include("height: 768")
      expect(script_content).to include("fullPage: true")
    end
  end

  describe "#validate_webchat_config" do
    let(:url) { "https://example.com/chat" }
    let(:config) do
      {
        selectors: {
          input_field: "#chat-input",
          send_button: "#send-btn",
          response_container: ".chat-messages"
        }
      }
    end

    context "when validation succeeds" do
      let(:success_response) do
        {
          "success" => true,
          "errors" => [],
          "response_detected" => true,
          "test_message_found" => true,
          "baseline_length" => 100,
          "new_length" => 150
        }.to_json
      end

      before do
        allow(Open3).to receive(:capture3).and_return([ success_response, "", double(success?: true) ])
      end

      it "returns success result" do
        result = service.validate_webchat_config(url, config)

        expect(result[:success]).to be true
        expect(result[:response_detected]).to be true
        expect(result[:errors]).to eq([])
      end

      it "includes response metrics" do
        result = service.validate_webchat_config(url, config)

        expect(result[:test_message_found]).to be true
        expect(result[:baseline_length]).to eq(100)
        expect(result[:new_length]).to eq(150)
      end
    end

    context "when validation fails" do
      let(:failure_response) do
        {
          "success" => false,
          "errors" => [ "Input field not found: #chat-input" ],
          "response_detected" => false
        }.to_json
      end

      before do
        allow(Open3).to receive(:capture3).and_return([ failure_response, "", double(success?: true) ])
      end

      it "returns failure result with errors" do
        result = service.validate_webchat_config(url, config)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Input field not found: #chat-input")
        expect(result[:response_detected]).to be false
      end
    end

    context "when script execution fails" do
      before do
        allow(Open3).to receive(:capture3).and_return([ "", "Node.js error", double(success?: false) ])
        allow(Rails.logger).to receive(:error)
      end

      it "returns error result" do
        result = service.validate_webchat_config(url, config)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_an(Array)
        expect(result[:errors].first).to match(/Node.js error|Unknown validation error/)
      end
    end

    it "accepts config as hash with string keys" do
      string_config = {
        "selectors" => {
          "input_field" => "#input",
          "response_container" => "#response"
        }
      }

      allow(Open3).to receive(:capture3).and_return([
        { "success" => true, "errors" => [], "response_detected" => true }.to_json,
        "",
        double(success?: true)
      ])

      result = service.validate_webchat_config(url, string_config)
      expect(result[:success]).to be true
    end

    it "includes custom wait times if provided" do
      config_with_wait = config.merge(
        wait_times: {
          page_load: 60000,
          response: 10000
        }
      )

      script_content = nil
      allow(Open3).to receive(:capture3) do |_env, _command, script_path|
        script_content = File.read(script_path)
        [
          { "success" => true, "errors" => [], "response_detected" => true }.to_json,
          "",
          double(success?: true)
        ]
      end

      service.validate_webchat_config(url, config_with_wait)

      expect(script_content).to include("timeout: 60000")
      expect(script_content).to include("waitForTimeout(10000)")
    end
  end

  describe "#extract_page_structure" do
    let(:url) { "https://example.com/chat" }
    let(:page_data) do
      {
        "html" => {
          "elements" => {
            "inputs" => [ { "selector" => "#input", "type" => "text" } ],
            "buttons" => [ { "selector" => "#button", "text" => "Send" } ],
            "containers" => [ { "selector" => ".container", "height" => 500 } ]
          },
          "title" => "Example Chat",
          "url" => url
        },
        "metadata" => {
          "title" => "Example Chat",
          "url" => url
        },
        "screenshot" => "base64_encoded_image_data"
      }
    end

    let(:success_response) do
      {
        "success" => true,
        "data" => page_data
      }.to_json
    end

    before do
      allow(Open3).to receive(:capture3).and_return([ success_response, "", double(success?: true) ])
    end

    it "returns page data on success" do
      result = service.extract_page_structure(url)

      expect(result).to eq(page_data)
      expect(result["html"]["elements"]["inputs"]).to be_an(Array)
      expect(result["screenshot"]).to eq("base64_encoded_image_data")
    end

    it "raises error when extraction fails" do
      allow(Open3).to receive(:capture3).and_return([
        { "error" => "Page load timeout" }.to_json,
        "",
        double(success?: true)
      ])

      expect {
        service.extract_page_structure(url)
      }.to raise_error("Page structure extraction failed: Page load timeout")
    end

    it "raises error on unexpected result format" do
      allow(Open3).to receive(:capture3).and_return([
        { "unexpected" => "format" }.to_json,
        "",
        double(success?: true)
      ])

      expect {
        service.extract_page_structure(url)
      }.to raise_error(/Unexpected result format/)
    end

    it "accepts custom options" do
      options = { width: 1024, height: 768, timeout: 20000 }
      script_content = nil

      allow(Open3).to receive(:capture3) do |_env, _command, script_path|
        script_content = File.read(script_path)
        [ success_response, "", double(success?: true) ]
      end

      service.extract_page_structure(url, options)

      expect(script_content).to include("width: 1024")
      expect(script_content).to include("height: 768")
      expect(script_content).to include("timeout: 20000")
    end
  end

  describe "#stop_browser" do
    it "does nothing when no browser process exists" do
      expect { service.stop_browser }.not_to raise_error
    end

    it "kills browser process if it exists" do
      pid = 12345
      service.instance_variable_set(:@browser_process, pid)

      allow(Process).to receive(:kill)
      allow(Process).to receive(:wait)

      service.stop_browser

      expect(Process).to have_received(:kill).with("TERM", pid)
      expect(Process).to have_received(:wait).with(pid)
    end

    it "handles process kill errors gracefully" do
      pid = 12345
      service.instance_variable_set(:@browser_process, pid)

      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
      allow(Process).to receive(:wait)

      expect { service.stop_browser }.not_to raise_error
    end

    it "resets browser_ready flag" do
      pid = 12345
      service.instance_variable_set(:@browser_process, pid)
      service.instance_variable_set(:@browser_ready, true)

      allow(Process).to receive(:kill)
      allow(Process).to receive(:wait)

      service.stop_browser

      expect(service.browser_ready).to be false
    end
  end

  describe "private methods" do
    describe "#execute_playwright_script" do
      it "creates temporary script file" do
        script = "console.log('test');"
        allow(Open3).to receive(:capture3).and_return([
          { "success" => true }.to_json,
          "",
          double(success?: true)
        ])

        service.send(:execute_playwright_script, script)

        expect(Open3).to have_received(:capture3) do |env, command, script_path|
          expect(env["NODE_PATH"]).to eq(Rails.root.join("node_modules").to_s)
          expect(command).to eq("node")
          expect(File.exist?(script_path)).to be false # Temp file should be cleaned up
        end
      end

      it "parses JSON output correctly" do
        script = "console.log('test');"
        json_output = { "success" => true, "data" => "result" }.to_json

        allow(Open3).to receive(:capture3).and_return([ json_output, "", double(success?: true) ])

        result = service.send(:execute_playwright_script, script)

        expect(result).to eq({ "success" => true, "data" => "result" })
      end

      it "handles non-JSON output" do
        script = "console.log('test');"
        allow(Open3).to receive(:capture3).and_return([ "Not JSON output", "", double(success?: true) ])
        allow(Rails.logger).to receive(:error)

        result = service.send(:execute_playwright_script, script)

        expect(result["error"]).to include("No JSON found in output")
      end

      it "handles JSON parse errors" do
        script = "console.log('test');"
        allow(Open3).to receive(:capture3).and_return([ "{invalid json}", "", double(success?: true) ])
        allow(Rails.logger).to receive(:error)

        result = service.send(:execute_playwright_script, script)

        # Now treated as a generic no-JSON case with stdout/stderr attached
        expect(result["error"]).to include("No JSON found in output")
      end

      it "cleans up temporary file even on error" do
        script = "console.log('test');"
        temp_file = instance_double(Tempfile)
        allow(Tempfile).to receive(:new).and_return(temp_file)
        allow(temp_file).to receive(:write)
        allow(temp_file).to receive(:close)
        allow(temp_file).to receive(:path).and_return("/tmp/test.js")
        allow(temp_file).to receive(:unlink)

        allow(Open3).to receive(:capture3).and_raise(StandardError)

        expect { service.send(:execute_playwright_script, script) }.to raise_error(StandardError)
        expect(temp_file).to have_received(:unlink)
      end
    end

    describe "#generate_screenshot_path" do
      it "generates path with timestamp" do
        allow(Time).to receive(:current).and_return(Time.new(2025, 1, 15, 12, 30, 45))
        allow(FileUtils).to receive(:mkdir_p)

        path = service.send(:generate_screenshot_path)

        expect(path.to_s).to include("20250115_123045")
        expect(path.to_s).to include("storage/screenshots")
        expect(path.to_s).to end_with(".png")
      end

      it "creates screenshots directory if needed" do
        expect(FileUtils).to receive(:mkdir_p)

        service.send(:generate_screenshot_path)
      end
    end

    describe "#build_page_script" do
      it "includes URL when provided" do
        script = service.send(:build_page_script, "https://example.com", {})

        expect(script).to include("await page.goto('https://example.com'")
      end

      it "omits goto when URL is nil" do
        script = service.send(:build_page_script, nil, {})

        expect(script).to include("// No URL provided")
        expect(script).not_to include("await page.goto")
      end

      it "respects headless option" do
        script = service.send(:build_page_script, "https://example.com", { headless: false })

        expect(script).to include("headless: false")
      end

      it "uses custom viewport dimensions" do
        script = service.send(:build_page_script, "https://example.com", { width: 800, height: 600 })

        expect(script).to include("width: 800")
        expect(script).to include("height: 600")
      end

      it "uses custom wait_until strategy" do
        script = service.send(:build_page_script, "https://example.com", { wait_until: "load" })

        expect(script).to include("waitUntil: 'load'")
      end
    end
  end

  describe "thread safety" do
    it "uses mutex for script execution" do
      mutex = service.instance_variable_get(:@mutex)
      expect(mutex).to be_a(Mutex)

      allow(Open3).to receive(:capture3).and_return([
        { "success" => true }.to_json,
        "",
        double(success?: true)
      ])

      expect(mutex).to receive(:synchronize).and_call_original

      service.send(:execute_playwright_script, "test script")
    end
  end
end
