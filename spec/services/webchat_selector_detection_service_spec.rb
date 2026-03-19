require "rails_helper"

RSpec.describe WebchatSelectorDetectionService do
  let(:url) { "https://example.com/chat" }
  let(:page_data) do
    {
      "metadata" => { "title" => "Example Chat" },
      "html" => {
        "elements" => {
          "inputs" => [
            {
              "selector" => "#chat-input",
              "type" => "text",
              "placeholder" => "Type a message",
              "role" => "textbox",
              "ariaLabel" => "Chat input"
            },
            {
              "selector" => "#search-box",
              "type" => "text",
              "placeholder" => "Search",
              "role" => nil,
              "ariaLabel" => nil
            }
          ],
          "buttons" => [
            {
              "selector" => "#send-btn",
              "text" => "Send",
              "role" => "button",
              "ariaLabel" => "Send message"
            },
            {
              "selector" => "#close-btn",
              "text" => "Close",
              "role" => "button",
              "ariaLabel" => nil
            }
          ],
          "containers" => [
            {
              "selector" => ".chat-messages",
              "height" => 500,
              "role" => "log",
              "ariaLabel" => "Chat history"
            },
            {
              "selector" => ".sidebar",
              "height" => 100,
              "role" => nil,
              "ariaLabel" => nil
            }
          ]
        }
      }
    }
  end

  let(:openai_client) { instance_double(OpenaiClient) }
  let(:service) { described_class.new(url, page_data) }

  before do
    allow(OpenaiClient).to receive(:new).and_return(openai_client)
  end

  describe "#initialize" do
    it "sets url and page_data" do
      expect(service.url).to eq(url)
      expect(service.page_data).to eq(page_data)
    end

    it "initializes OpenaiClient" do
      expect(service.client).to eq(openai_client)
    end
  end

  describe "#detect_selectors" do
    let(:llm_response) do
      {
        "selectors" => {
          "input_field" => "#chat-input",
          "send_button" => "#send-btn",
          "response_container" => ".chat-messages",
          "response_text" => ".chat-messages p"
        },
        "detection_confidence" => "high",
        "notes" => "Found all required elements"
      }
    end

    context "on first attempt" do
      before do
        allow(openai_client).to receive(:extract_structured_data).and_return(llm_response)
      end

      it "calls initial_detection" do
        result = service.detect_selectors(attempt: 1, previous_errors: [])

        expect(result).to be_a(Hash)
        expect(result[:selectors]).to include("input_field" => "#chat-input")
        expect(result[:selectors]).to include("send_button" => "#send-btn")
        expect(result[:selectors]).to include("response_container" => ".chat-messages")
        expect(result[:selectors]).to include("response_text" => ".chat-messages p")
      end

      it "includes confidence and notes" do
        result = service.detect_selectors(attempt: 1, previous_errors: [])

        expect(result[:confidence]).to eq("high")
        expect(result[:notes]).to eq("Found all required elements")
      end

      it "passes correct parameters to LLM" do
        expect(openai_client).to receive(:extract_structured_data).with(
          hash_including(
            prompt: include("Type a message"),  # Should include input placeholder
            schema: hash_including(type: "object"),
            system: include("expert at analyzing web pages")
          )
        )

        service.detect_selectors(attempt: 1, previous_errors: [])
      end
    end

    context "on retry attempt" do
      let(:previous_errors) { [ "Input field selector not found", "Container too small" ] }

      before do
        allow(openai_client).to receive(:extract_structured_data).and_return(llm_response)
      end

      it "calls retry_detection with error feedback" do
        result = service.detect_selectors(attempt: 2, previous_errors: previous_errors)

        expect(result).to be_a(Hash)
        expect(result[:selectors]).to be_present
      end

      it "includes previous errors in prompt" do
        expect(openai_client).to receive(:extract_structured_data).with(
          hash_including(
            prompt: include("previous selectors FAILED")
              .and(include("Input field selector not found"))
              .and(include("Container too small"))
          )
        )

        service.detect_selectors(attempt: 2, previous_errors: previous_errors)
      end

      it "instructs to select DIFFERENT selectors" do
        expect(openai_client).to receive(:extract_structured_data).with(
          hash_including(
            prompt: include("DIFFERENT selectors")
          )
        )

        service.detect_selectors(attempt: 2, previous_errors: previous_errors)
      end
    end

    context "when LLM returns invalid response" do
      before do
        allow(openai_client).to receive(:extract_structured_data).and_return(nil)
      end

      it "returns nil" do
        result = service.detect_selectors(attempt: 1, previous_errors: [])
        expect(result).to be_nil
      end
    end

    context "when LLM returns response without selectors" do
      before do
        allow(openai_client).to receive(:extract_structured_data).and_return({ "confidence" => "low" })
      end

      it "returns nil" do
        result = service.detect_selectors(attempt: 1, previous_errors: [])
        expect(result).to be_nil
      end
    end

    context "when LLM raises an error" do
      before do
        allow(openai_client).to receive(:extract_structured_data)
          .and_raise(StandardError, "API error")
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(include("Initial detection failed"))

        result = service.detect_selectors(attempt: 1, previous_errors: [])
        expect(result).to be_nil
      end
    end
  end

  describe "#build_comprehensive_prompt (private)" do
    let(:inputs) { [ "#input1 (type: text)", "#input2 (placeholder: 'Chat')" ] }
    let(:buttons) { [ "#btn1 (text: 'Send')" ] }
    let(:containers) { [ ".container1 (height: 500px)" ] }

    it "builds a prompt with all elements" do
      prompt = service.send(:build_comprehensive_prompt,
        url: url,
        title: "Test Chat",
        inputs: inputs,
        buttons: buttons,
        containers: containers
      )

      expect(prompt).to include(url)
      expect(prompt).to include("Test Chat")
      expect(prompt).to include("#input1")
      expect(prompt).to include("#input2")
      expect(prompt).to include("#btn1")
      expect(prompt).to include(".container1")
    end

    it "includes critical instructions" do
      prompt = service.send(:build_comprehensive_prompt,
        url: url,
        title: "Test",
        inputs: inputs,
        buttons: buttons,
        containers: containers
      )

      expect(prompt).to include("ONLY use selectors from")
      expect(prompt).to include("DO NOT invent")
      expect(prompt).to include("Prioritize semantic selectors")
    end

    it "includes element descriptions" do
      prompt = service.send(:build_comprehensive_prompt,
        url: url,
        title: "Test",
        inputs: inputs,
        buttons: buttons,
        containers: containers
      )

      expect(prompt).to include("input_field")
      expect(prompt).to include("send_button")
      expect(prompt).to include("response_container")
      expect(prompt).to include("response_text")
    end

    it "includes negative examples" do
      prompt = service.send(:build_comprehensive_prompt,
        url: url,
        title: "Test",
        inputs: inputs,
        buttons: buttons,
        containers: containers
      )

      expect(prompt).to include("INVENTING selectors")
      expect(prompt).to include("COMBINING real selectors")
      expect(prompt).to include("MODIFYING candidate selectors")
    end

    it "includes positive examples" do
      prompt = service.send(:build_comprehensive_prompt,
        url: url,
        title: "Test",
        inputs: inputs,
        buttons: buttons,
        containers: containers
      )

      expect(prompt).to include("EXACT copy of selector")
      expect(prompt).to include("Prioritizing semantic selectors")
      expect(prompt).to include("Setting fields to null")
    end
  end

  describe "element data preparation" do
    it "formats input elements correctly" do
      allow(openai_client).to receive(:extract_structured_data) do |params|
        prompt = params[:prompt]
        expect(prompt).to include("#chat-input")
        expect(prompt).to include("Type a message")
        expect(prompt).to include("role: 'textbox'")
        expect(prompt).to include("aria-label: 'Chat input'")

        llm_response = {
          "selectors" => {
            "input_field" => "#chat-input",
            "response_container" => ".chat-messages"
          },
          "detection_confidence" => "high"
        }
      end

      service.detect_selectors(attempt: 1, previous_errors: [])
    end

    it "formats button elements correctly" do
      allow(openai_client).to receive(:extract_structured_data) do |params|
        prompt = params[:prompt]
        expect(prompt).to include("#send-btn")
        expect(prompt).to include("text: 'Send'")
        expect(prompt).to include("aria-label: 'Send message'")

        llm_response = {
          "selectors" => {
            "input_field" => "#chat-input",
            "response_container" => ".chat-messages"
          },
          "detection_confidence" => "high"
        }
      end

      service.detect_selectors(attempt: 1, previous_errors: [])
    end

    it "formats container elements correctly" do
      allow(openai_client).to receive(:extract_structured_data) do |params|
        prompt = params[:prompt]
        expect(prompt).to include(".chat-messages")
        expect(prompt).to include("height: 500px")
        expect(prompt).to include("role: 'log'")

        llm_response = {
          "selectors" => {
            "input_field" => "#chat-input",
            "response_container" => ".chat-messages"
          },
          "detection_confidence" => "high"
        }
      end

      service.detect_selectors(attempt: 1, previous_errors: [])
    end

    it "limits elements to 15 per category" do
      large_page_data = {
        "metadata" => { "title" => "Test" },
        "html" => {
          "elements" => {
            "inputs" => Array.new(30) { |i| { "selector" => "#input-#{i}", "type" => "text" } },
            "buttons" => Array.new(30) { |i| { "selector" => "#btn-#{i}", "text" => "Btn #{i}" } },
            "containers" => Array.new(30) { |i| { "selector" => ".container-#{i}", "height" => 100 } }
          }
        }
      }

      service_large = described_class.new(url, large_page_data)

      allow(openai_client).to receive(:extract_structured_data) do |params|
        prompt = params[:prompt]

        # Should include first 15
        expect(prompt).to include("#input-0")
        expect(prompt).to include("#input-14")

        # Should NOT include 16th and beyond
        expect(prompt).not_to include("#input-15")
        expect(prompt).not_to include("#input-29")

        {
          "selectors" => {
            "input_field" => "#input-0",
            "response_container" => ".container-0"
          },
          "detection_confidence" => "high"
        }
      end

      service_large.detect_selectors(attempt: 1, previous_errors: [])
    end
  end
end
