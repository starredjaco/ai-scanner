class WebchatSelectorDetectionService
  attr_reader :url, :page_data, :client

  def initialize(url, page_data)
    @url = url
    @page_data = page_data
    @client = OpenaiClient.new
  end

  # Detect selectors with retry logic
  # attempt: current attempt number (1-3)
  # previous_errors: array of error messages from previous attempt
  def detect_selectors(attempt: 1, previous_errors: [])
    if attempt == 1
      response = initial_detection
    else
      response = retry_detection(previous_errors)
    end

    return nil unless response && response["selectors"]

    {
      selectors: {
        "input_field" => response["selectors"]["input_field"],
        "send_button" => response["selectors"]["send_button"],
        "response_container" => response["selectors"]["response_container"],
        "response_text" => response["selectors"]["response_text"]
      },
      confidence: response["detection_confidence"],
      notes: response["notes"]
    }
  end

  private

  def initial_detection
    elements = page_data["html"]["elements"]

    # Prepare candidate data (15 per category for better accuracy)
    inputs_data = elements["inputs"].first(15).map { |i|
      attrs = []
      attrs << "type: #{i['type']}" if i["type"]
      attrs << "placeholder: '#{i['placeholder']}'" if i["placeholder"].present?
      attrs << "role: '#{i['role']}'" if i["role"].present?
      attrs << "aria-label: '#{i['ariaLabel']}'" if i["ariaLabel"].present?
      "#{i['selector']} (#{attrs.join(', ')})"
    }

    buttons_data = elements["buttons"].first(15).map { |b|
      attrs = []
      attrs << "text: '#{b['text'][0..50]}'" if b["text"].present?
      attrs << "role: '#{b['role']}'" if b["role"].present?
      attrs << "aria-label: '#{b['ariaLabel']}'" if b["ariaLabel"].present?
      "#{b['selector']} (#{attrs.join(', ')})"
    }

    containers_data = elements["containers"].first(15).map { |c|
      attrs = []
      attrs << "height: #{c['height'].to_i}px" if c["height"]
      attrs << "role: '#{c['role']}'" if c["role"].present?
      attrs << "aria-label: '#{c['ariaLabel']}'" if c["ariaLabel"].present?
      "#{c['selector']} (#{attrs.join(', ')})"
    }

    # Build comprehensive Phase 1 prompt
    prompt = build_comprehensive_prompt(
      url: url,
      title: page_data["metadata"]["title"],
      inputs: inputs_data,
      buttons: buttons_data,
      containers: containers_data
    )

    # Define schema
    schema = {
      type: "object",
      properties: {
        selectors: {
          type: "object",
          properties: {
            input_field: { type: "string" },
            send_button: { type: "string" },
            response_container: { type: "string" },
            response_text: { type: "string" }
          },
          required: [ "input_field", "response_container" ]
        },
        detection_confidence: { type: "string", enum: [ "high", "medium", "low" ] },
        notes: { type: "string" }
      },
      required: [ "selectors", "detection_confidence" ]
    }

    # Call LLM
    system_message = "You are an expert at analyzing web pages and identifying chat interface elements. Always provide accurate CSS selectors."

    client.extract_structured_data(
      prompt: prompt,
      schema: schema,
      system: system_message
    )
  rescue StandardError => e
    Rails.logger.error("Initial detection failed: #{e.message}")
    nil
  end

  def retry_detection(previous_errors)
    elements = page_data["html"]["elements"]

    # Prepare candidate data again
    inputs_data = elements["inputs"].first(15).map { |i|
      attrs = []
      attrs << "type: #{i['type']}" if i["type"]
      attrs << "placeholder: '#{i['placeholder']}'" if i["placeholder"].present?
      attrs << "role: '#{i['role']}'" if i["role"].present?
      attrs << "aria-label: '#{i['ariaLabel']}'" if i["ariaLabel"].present?
      "#{i['selector']} (#{attrs.join(', ')})"
    }

    containers_data = elements["containers"].first(15).map { |c|
      attrs = []
      attrs << "height: #{c['height'].to_i}px" if c["height"]
      attrs << "role: '#{c['role']}'" if c["role"].present?
      "#{c['selector']} (#{attrs.join(', ')})"
    }

    # Build retry prompt with error feedback
    retry_prompt = <<~RETRY_PROMPT
      Your previous selectors FAILED validation with these errors:
      #{previous_errors.map { |e| "  - #{e}" }.join("\n")}

      Please select DIFFERENT selectors from the original candidate list below.
      DO NOT reuse selectors that failed. Try different options.

      Original candidates:
      Inputs: #{inputs_data.join(', ')}
      Containers: #{containers_data.join(', ')}

      CRITICAL INSTRUCTIONS:
      1. If input_field failed "not found", pick a DIFFERENT input from the list
      2. If response_container failed "not found", pick a DIFFERENT container
      3. ONLY use selectors that appear in the candidates above
      4. DO NOT invent or modify selectors
      5. Prioritize semantic selectors: [role="textbox"], #id
    RETRY_PROMPT

    schema = {
      type: "object",
      properties: {
        selectors: {
          type: "object",
          properties: {
            input_field: { type: "string" },
            send_button: { type: "string" },
            response_container: { type: "string" },
            response_text: { type: "string" }
          },
          required: [ "input_field", "response_container" ]
        },
        detection_confidence: { type: "string", enum: [ "high", "medium", "low" ] },
        notes: { type: "string" }
      },
      required: [ "selectors", "detection_confidence" ]
    }

    system_message = "You are an expert at analyzing web pages and identifying chat interface elements. Always provide accurate CSS selectors."

    client.extract_structured_data(
      prompt: retry_prompt,
      schema: schema,
      system: system_message
    )
  rescue StandardError => e
    Rails.logger.error("Retry detection failed: #{e.message}")
    nil
  end

  def build_comprehensive_prompt(url:, title:, inputs:, buttons:, containers:)
    <<~PROMPT
      Analyze this web chat interface and identify the CSS selectors for chat elements.

      URL: #{url}
      Page Title: #{title}

      Available Elements (CANDIDATES ONLY):
      Inputs: #{inputs.join(', ')}
      Buttons: #{buttons.join(', ')}
      Containers: #{containers.join(', ')}

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      CRITICAL RULES - READ CAREFULLY:
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      1. 🚨 ONLY use selectors from the "Available Elements" list above
      2. 🚨 DO NOT invent, guess, or create new selectors
      3. 🚨 If you cannot find a suitable element, set it to null
      4. ✅ Prioritize semantic selectors: [role="textbox"] > #id > .class
      5. ✅ Look for chat-specific keywords in placeholders and text
      6. ❌ Avoid generic elements like search boxes, navigation, login fields

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      Your Task:
      1. input_field: The MAIN chat input where users type messages
         - Look for: placeholders like "Type a message", "Ask me anything", "Enter prompt"
         - Semantic attributes: role="textbox", aria-label containing "chat" or "message"
         - Avoid: search boxes, login fields, navigation inputs

      2. send_button: The button to submit the chat message
         - Look for: text like "Send", "Submit", or arrow icons
         - Can be null if Enter key is used instead
         - Avoid: navigation buttons, "New Chat", "Clear" buttons

      3. response_container: The area displaying the conversation history
         - Look for: large containers with role="log" or high height
         - Usually a scrollable div containing multiple messages
         - Avoid: headers, footers, sidebars

      4. response_text: The selector for individual message text elements
         - Look for: paragraph tags, message divs within the container
         - Often combined with response_container selector
         - Example: .messages p, .chat-container .message-text

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      Validation Criteria:
      - Input field should be visible and accept text input
      - Send button (if exists) should trigger message submission
      - Response container should show conversation history
      - Response text should extract actual message content

      Confidence Assessment:
      - HIGH: All required elements found with specific, semantic selectors
      - MEDIUM: Found elements but using generic class names
      - LOW: Uncertain about selections or missing optional elements

      Negative Examples - CRITICAL (DO NOT DO THIS):

      ❌ INVENTING selectors not in the candidate list:
         BAD:  ".chat-container .message-text" (if .message-text NOT in candidates)
         WHY:  You created ".message-text" which doesn't exist on the page
         FIX:  Use ONLY selectors that appear in the candidate list above

      ❌ COMBINING real selectors with fake class names:
         BAD:  ".chat-app .bot-message p" (if .bot-message NOT in candidates)
         WHY:  Only .chat-app exists, you invented .bot-message
         FIX:  If you need a child selector, set response_text to null

      ❌ MODIFYING candidate selectors:
         BAD:  ".chat-container-main" (when candidate is ".chat-container")
         WHY:  You added "-main" which changes the selector completely
         FIX:  Copy the exact selector string from candidates

      ❌ Using overly broad selectors:
         BAD:  "div" or ".flex" or "main"
         WHY:  Matches hundreds of elements, will select wrong ones
         FIX:  Use specific selectors from candidate list

      ❌ Selecting navigation/search elements instead of chat:
         BAD:  Choosing input with placeholder "Search" for chat input
         WHY:  Search boxes are not chat inputs
         FIX:  Look for chat-specific keywords in placeholders

      Positive Examples - FOLLOW THESE (DO THIS):

      ✅ EXACT copy of selector from candidate list:
         GOOD: ".chat-container.ng-tns-c3371048223-1.ng-trigger"
         WHY:  This exact string appears in containers list

      ✅ Prioritizing semantic selectors over classes:
         GOOD: [role="textbox"] instead of .ql-editor
         WHY:  Role attributes are stable and semantic

      ✅ Setting fields to null when uncertain:
         GOOD: "send_button": null (if no send button in candidates)
         WHY:  Honesty is better than guessing

      ✅ Using only container selector for response_text:
         GOOD: "response_text": ".chat-history" (if it's in candidates)
         WHY:  Better to use container than invent child selectors
    PROMPT
  end
end
