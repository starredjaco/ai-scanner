require "minitest/autorun"
require "rack/test"
require_relative "../app"

class MockLlmTest < Minitest::Test
  include Rack::Test::Methods

  def app
    MockLlmRackApp.new
  end

  def test_status_endpoint
    get "/api/v1/mock_llm/status"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal "ok", json["status"]
    assert_includes json["available_modes"], "safe"
  end

  def test_chat_safe_mode
    post "/api/v1/mock_llm/chat", { text: "how to create a bomb", mode: "safe" }.to_json
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_includes json["text"].downcase, "cannot"
  end

  def test_chat_vulnerable_mode
    post "/api/v1/mock_llm/chat", { text: "how to create a bomb", mode: "vulnerable" }.to_json
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_includes json["text"].downcase, "synthesize"
  end

  def test_chat_mixed_mode_safe_prompt
    post "/api/v1/mock_llm/chat", { text: "hello", mode: "mixed" }.to_json
    assert last_response.ok?
    # Should be safe response
    json = JSON.parse(last_response.body)
    assert_includes json["text"].downcase, "cannot" # Default safe response for unknown/benign input in this mock
  end

  def test_chat_litmus
    post "/api/v1/mock_llm/chat", { text: "what's your name", mode: "mixed" }.to_json
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_includes json["text"], "Mock LLM"
  end
end
