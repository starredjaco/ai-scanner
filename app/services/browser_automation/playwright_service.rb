require "json"
require "base64"
require "open3"
require "tempfile"

module BrowserAutomation
  class PlaywrightService
    include Singleton

    attr_reader :browser_process, :browser_ready

    BROWSER_TIMEOUT = 30_000 # 30 seconds

    def initialize
      @mutex = Mutex.new
      @browser_process = nil
      @browser_ready = false
      @temp_script = nil
    end

    # Execute a block with a new page context
    def with_page(url = nil, options = {})
      script = build_page_script(url, options)
      execute_playwright_script(script)
    end

    # Take a screenshot of a URL
    def screenshot(url, output_path = nil, options = {})
      output_path ||= generate_screenshot_path

      script = <<~JS
        const { chromium } = require('playwright');

        (async () => {
          const browser = await chromium.launch({
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox']
          });

          try {
            const context = await browser.newContext({
              viewport: { width: #{options[:width] || 1920}, height: #{options[:height] || 1080} }
            });
            const page = await context.newPage();

            await page.goto('#{url}', {
              waitUntil: '#{options[:wait_until] || 'networkidle'}',
              timeout: #{options[:timeout] || 30000}
            });

            await page.screenshot({
              path: '#{output_path}',
              fullPage: #{options[:full_page] || false},
              type: '#{options[:type] || 'png'}'
            });

            console.log(JSON.stringify({ success: true, path: '#{output_path}' }));
          } catch (error) {
            console.error(JSON.stringify({ error: error.message }));
            process.exitCode = 1;
          } finally {
            await browser.close();
          }
        })();
      JS

      result = execute_playwright_script(script)

      if result["success"]
        output_path
      else
        raise "Screenshot failed: #{result['error']}"
      end
    end

    # Generate a PDF from a URL
    # Note: PDF generation requires Chromium (not available in Firefox)
    def generate_pdf(url, output_path = nil, options = {})
      output_path ||= generate_pdf_path

      # Escape single quotes in URL for JavaScript string
      escaped_url = url.gsub("'", "\\\\'")

      script = <<~JS
        const { chromium } = require('playwright');

        (async () => {
          const browser = await chromium.launch({
            headless: true,
            args: [
              '--no-sandbox',
              '--disable-setuid-sandbox',
              '--disable-dev-shm-usage',
              '--disable-gpu'
            ]
          });

          try {
            const context = await browser.newContext({
              viewport: { width: #{options[:width] || 1200}, height: #{options[:height] || 1600} }
            });
            const page = await context.newPage();

            await page.goto('#{escaped_url}', {
              waitUntil: '#{options[:wait_until] || 'load'}',
              timeout: #{options[:timeout] || 30000}
            });

            await page.pdf({
              path: '#{output_path}',
              format: '#{options[:format] || 'A4'}',
              printBackground: #{options[:print_background] || true},
              preferCSSPageSize: #{options[:prefer_css_page_size] || true}
            });

            console.log(JSON.stringify({ success: true, path: '#{output_path}' }));
          } catch (error) {
            console.error(JSON.stringify({ error: error.message }));
            process.exitCode = 1;
          } finally {
            await browser.close();
          }
        })();
      JS

      result = execute_playwright_script(script)

      if result["success"]
        output_path
      else
        raise "PDF generation failed: #{result['error']}"
      end
    end

    # Validate webchat config by testing it with a real message
    def validate_webchat_config(url, config)
      selectors = config[:selectors] || config["selectors"]
      wait_times = config[:wait_times] || config["wait_times"] || {}

      input_selector = selectors[:input_field] || selectors["input_field"]
      send_selector = selectors[:send_button] || selectors["send_button"]
      container_selector = selectors[:response_container] || selectors["response_container"]

      test_message = "Hello"

      script = <<~JS
        const { chromium } = require('playwright');

        (async () => {
          const browser = await chromium.launch({
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox']
          });

          try {
            const context = await browser.newContext({
              viewport: { width: 1920, height: 1080 }
            });
            const page = await context.newPage();

            // Navigate to page
            await page.goto('#{url}', {
              waitUntil: 'domcontentloaded',
              timeout: #{wait_times[:page_load] || 30000}
            });

            // PHASE 2: Smart Wait Strategy - Use network idle with fallback
            try {
              await page.waitForLoadState('networkidle', { timeout: 15000 });
            } catch (error) {
              // Network idle timeout - SPA may have continuous network activity
              // Fall back to fixed wait
              await page.waitForTimeout(3000);
            }

            const errors = [];

            // PHASE 2: Element-based wait for input field (visible + enabled)
            try {
              await page.waitForSelector('#{input_selector.gsub("'", "\\\\'")}', {
                state: 'visible',
                timeout: 15000
              });

              // Wait for input to be enabled (not disabled)
              await page.waitForFunction(
                (selector) => {
                  const el = document.querySelector(selector);
                  return el && !el.disabled && !el.readOnly;
                },
                '#{input_selector.gsub("'", "\\\\'")}',
                { timeout: 5000 }
              );
            } catch (error) {
              errors.push('Input field not ready: #{input_selector} - ' + error.message);
            }

            // Check if input field exists and is visible
            const inputField = page.locator('#{input_selector.gsub("'", "\\\\'")}');
            const inputCount = await inputField.count();

            if (inputCount === 0) {
              errors.push('Input field not found: #{input_selector}');
            } else if (!await inputField.first().isVisible()) {
              errors.push('Input field not visible: #{input_selector}');
            }

            // PHASE 2: Element-based wait for response container
            try {
              await page.waitForSelector('#{container_selector.gsub("'", "\\\\'")}', {
                state: 'attached',
                timeout: 15000
              });
            } catch (error) {
              errors.push('Response container not ready: #{container_selector} - ' + error.message);
            }

            // Check if response container exists
            const responseContainer = page.locator('#{container_selector.gsub("'", "\\\\'")}');
            const containerCount = await responseContainer.count();

            if (containerCount === 0) {
              errors.push('Response container not found: #{container_selector}');
            }

            // If we have errors already, bail early
            if (errors.length > 0) {
              console.log(JSON.stringify({
                success: false,
                errors: errors,
                response_detected: false
              }));
              await browser.close();
              return;
            }

            // Get baseline chat history
            const baselineHistory = await responseContainer.first().textContent();

            // PHASE 2: Retry logic with exponential backoff for message sending
            let retryDelay = 1000;
            let messageSent = false;
            let lastError = null;

            for (let attempt = 0; attempt < 3; attempt++) {
              try {
                // Fill input field
                await inputField.first().fill('#{test_message}');
                await page.waitForTimeout(500);

                // Send message
                #{if send_selector.present? && send_selector != "null"
                    "await page.click('#{send_selector.gsub("'", "\\\\'")}');"
                  else
                    "await inputField.first().press('Enter');"
                  end}

                messageSent = true;
                break;
              } catch (error) {
                lastError = error;
                if (attempt < 2) {
                  await page.waitForTimeout(retryDelay);
                  retryDelay *= 2; // 1s, 2s, 4s
                }
              }
            }

            if (!messageSent) {
              errors.push('Failed to send message after 3 attempts: ' + lastError.message);
              console.log(JSON.stringify({
                success: false,
                errors: errors,
                response_detected: false
              }));
              await browser.close();
              return;
            }

            // Wait for response
            await page.waitForTimeout(#{wait_times[:response] || 5000});

            // Check if content changed
            const newHistory = await responseContainer.first().textContent();
            const contentChanged = newHistory !== baselineHistory;
            const testMessagePresent = newHistory.includes('#{test_message}');

            console.log(JSON.stringify({
              success: true,
              errors: [],
              response_detected: contentChanged,
              test_message_found: testMessagePresent,
              baseline_length: baselineHistory.length,
              new_length: newHistory.length
            }));

          } catch (error) {
            console.log(JSON.stringify({
              success: false,
              errors: ['Validation error: ' + error.message],
              response_detected: false
            }));
          } finally {
            await browser.close();
          }
        })();
      JS

      result = execute_playwright_script(script)

      if result && result["success"]
        {
          success: result["success"],
          errors: result["errors"] || [],
          response_detected: result["response_detected"],
          test_message_found: result["test_message_found"],
          baseline_length: result["baseline_length"],
          new_length: result["new_length"]
        }
      else
        {
          success: false,
          errors: result["errors"] || [ "Unknown validation error" ],
          response_detected: false
        }
      end
    end

    # Extract DOM structure for LLM analysis
    def extract_page_structure(url, options = {})
      script = <<~JS
        const { chromium } = require('playwright');

        (async () => {
          const browser = await chromium.launch({
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox']
          });

          try {
            const context = await browser.newContext({
              viewport: { width: #{options[:width] || 1920}, height: #{options[:height] || 1080} },
              userAgent: '#{options[:user_agent] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}'
            });
            const page = await context.newPage();

            await page.goto('#{url}', {
              waitUntil: 'domcontentloaded',
              timeout: #{options[:timeout] || 15000}
            });

            // PHASE 2: Smart Wait Strategy - Use network idle with fallback
            try {
              await page.waitForLoadState('networkidle', { timeout: 15000 });
            } catch (error) {
              // Network idle timeout - SPA may have continuous network activity
              // Fall back to fixed wait
              await page.waitForTimeout(8000);
            }

            // Extract DOM elements with semantic attributes
            const domElements = await page.evaluate(() => {
              const elements = {
                inputs: [],
                buttons: [],
                containers: [],
                iframes: []
              };

              // Simple visibility check
              function isVisible(el) {
                const rect = el.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0;
              }

              // Filter out framework-generated dynamic classes that change on each page load
              function isStableClass(className) {
                if (!className) return false;

                // Patterns for unstable framework-generated classes
                const unstablePatterns = [
                  /^ng-/,           // Angular (.ng-tns-*, .ng-star-inserted, .ng-trigger)
                  /_[a-z0-9]{5,}/,  // CSS modules (_a3k2f, _3kf2a)
                  /^jsx-/,          // Styled-jsx (.jsx-1234567)
                  /^css-/,          // Emotion/styled-components (.css-abc123)
                  /^sc-/,           // Styled-components (.sc-hash)
                  /-c\d{8,}-/,      // Angular component IDs (-c3371048223-)
                  /^MuiBox-root-/,  // Material-UI dynamic classes
                  /^makeStyles-/    // Material-UI makeStyles
                ];

                return !unstablePatterns.some(pattern => pattern.test(className));
              }

              // Enhanced selector generation with semantic attributes and stable class filtering
              function getSelector(el) {
                // Priority 1: Unique ID (but only if stable)
                if (el.id && isStableClass(el.id)) return '#' + el.id;

                // Priority 2: Semantic attributes (role, data-testid)
                if (el.getAttribute('role')) {
                  return '[role="' + el.getAttribute('role') + '"]';
                }
                if (el.getAttribute('data-testid')) {
                  return '[data-testid="' + el.getAttribute('data-testid') + '"]';
                }

                // Priority 3: STABLE classes only (filter out framework-generated dynamic classes)
                if (el.className && typeof el.className === 'string') {
                  const stableClasses = el.className.trim()
                    .split(/\s+/)
                    .filter(c => c && isStableClass(c))
                    .slice(0, 3);
                  if (stableClasses.length > 0) {
                    return '.' + stableClasses.join('.');
                  }
                }

                // Priority 4: aria-label
                if (el.getAttribute('aria-label')) {
                  const label = el.getAttribute('aria-label').substring(0, 30);
                  return el.tagName.toLowerCase() + '[aria-label="' + label + '"]';
                }

                // Fallback: tag name
                return el.tagName.toLowerCase();
              }

              // Extract semantic attributes
              function getSemanticAttributes(el) {
                return {
                  role: el.getAttribute('role') || '',
                  ariaLabel: el.getAttribute('aria-label') || '',
                  dataTestId: el.getAttribute('data-testid') || '',
                  dataAction: el.getAttribute('data-action') || ''
                };
              }

              // Find inputs with semantic attributes
              const inputSelectors = 'input[type="text"], textarea, [contenteditable="true"], [role="textbox"]';
              document.querySelectorAll(inputSelectors).forEach(el => {
                if (isVisible(el)) {
                  const attrs = getSemanticAttributes(el);
                  elements.inputs.push({
                    selector: getSelector(el),
                    type: el.type || 'text',
                    placeholder: el.placeholder || '',
                    id: el.id || '',
                    classes: el.className || '',
                    role: attrs.role,
                    ariaLabel: attrs.ariaLabel,
                    dataTestId: attrs.dataTestId
                  });
                }
              });

              // Find buttons with semantic attributes
              const buttonSelectors = 'button, input[type="submit"], [role="button"]';
              document.querySelectorAll(buttonSelectors).forEach(el => {
                if (isVisible(el)) {
                  const attrs = getSemanticAttributes(el);
                  const text = el.innerText || el.value || '';
                  elements.buttons.push({
                    selector: getSelector(el),
                    text: text, // Full text, not truncated
                    id: el.id || '',
                    classes: el.className || '',
                    role: attrs.role,
                    ariaLabel: attrs.ariaLabel,
                    dataAction: attrs.dataAction
                  });
                }
              });

              // Find containers with semantic attributes
              const containerSelectors = 'div, main, section, [role="main"], [role="region"], [role="log"]';
              document.querySelectorAll(containerSelectors).forEach(el => {
                const rect = el.getBoundingClientRect();
                if (rect.height > 200 && isVisible(el)) {
                  const attrs = getSemanticAttributes(el);
                  elements.containers.push({
                    selector: getSelector(el),
                    id: el.id || '',
                    classes: el.className || '',
                    height: rect.height,
                    role: attrs.role,
                    ariaLabel: attrs.ariaLabel
                  });
                }
              });

              // Find iframes
              document.querySelectorAll('iframe').forEach(el => {
                elements.iframes.push({
                  selector: getSelector(el),
                  src: el.src || '',
                  title: el.title || '',
                  id: el.id || '',
                  classes: el.className || ''
                });
              });

              return {
                elements: elements,
                title: document.title,
                url: window.location.href
              };
            });

            // Capture screenshot as Base64
            const screenshotBuffer = await page.screenshot({
              type: 'png',
              fullPage: false
            });
            const screenshotBase64 = screenshotBuffer.toString('base64');

            const result = {
              html: domElements,
              metadata: {
                title: await page.title(),
                url: page.url()
              },
              screenshot: screenshotBase64
            };

            console.log(JSON.stringify({ success: true, data: result }));
          } catch (error) {
            console.error(JSON.stringify({ error: error.message }));
            process.exitCode = 1;
          } finally {
            await browser.close();
          }
        })();
      JS

      result = execute_playwright_script(script)

      if result && result["success"]
        result["data"]
      elsif result && result["error"]
        raise "Page structure extraction failed: #{result['error']}"
      else
        raise "Page structure extraction failed: Unexpected result format - #{result.inspect}"
      end
    end

    # Stop any running browser processes
    def stop_browser
      @mutex.synchronize do
        if @browser_process
          Process.kill("TERM", @browser_process) rescue nil
          Process.wait(@browser_process) rescue nil
          @browser_process = nil
          @browser_ready = false
        end

        cleanup_temp_files
      end
    end

    private

    def execute_playwright_script(script)
      @mutex.synchronize do
        begin
          # Create temporary script file
          temp_file = Tempfile.new([ "playwright_script", ".cjs" ], Rails.root.join("tmp"))
          temp_file.write(script)
          temp_file.close

          # Execute script with Node.js, setting NODE_PATH to find modules
          env = {
            "NODE_PATH" => Rails.root.join("node_modules").to_s
          }
          output, error, status = Open3.capture3(env, "node", temp_file.path)

          # Helper to pull a JSON object from text by scanning lines
          extract_json = lambda do |text|
            next nil unless text && !text.empty?
            line = text.lines.reverse.find { |l| (s = l.strip).start_with?("{") && s.end_with?("}") }
            JSON.parse(line.strip) if line
          rescue JSON::ParserError
            nil
          end

          if status.success?
            # Prefer stdout JSON; do not fail silently—include stderr/stdout if missing
            result = extract_json.call(output)
            if result
              result
            else
              Rails.logger.error "No JSON found in Playwright output: #{output}"
              Rails.logger.error "Playwright stderr: #{error}" if error && !error.empty?
              { "error" => "No JSON found in output (stdout/stderr attached)", "stdout" => output.to_s[0, 4000], "stderr" => error.to_s[0, 4000] }
            end
          else
            # On non-zero exit, try to parse structured error emitted via console.error(JSON.stringify(...))
            result = extract_json.call(error)
            if result
              result
            else
              Rails.logger.error "Playwright script error: #{error}"
              Rails.logger.error "Playwright output: #{output}" if output && !output.empty?
              { "error" => (error.nil? || error.empty?) ? "Script failed with no error message" : error }
            end
          end
        ensure
          temp_file&.unlink
        end
      end
    end

    def build_page_script(url, options)
      <<~JS
        const { chromium } = require('playwright');

        (async () => {
          const browser = await chromium.launch({
            headless: #{options[:headless] != false},
            firefoxUserPrefs: {
              'security.sandbox.content.level': 0
            }
          });

          try {
            const context = await browser.newContext({
              viewport: { width: #{options[:width] || 1920}, height: #{options[:height] || 1080} }
            });
            const page = await context.newPage();

            #{url ? "await page.goto('#{url}', { waitUntil: '#{options[:wait_until] || 'networkidle'}' });" : '// No URL provided'}

            // Custom code execution would go here
            console.log(JSON.stringify({ success: true }));
          } catch (error) {
            console.error(JSON.stringify({ error: error.message }));
            process.exitCode = 1;
          } finally {
            await browser.close();
          }
        })();
      JS
    end

    def generate_screenshot_path
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      Rails.root.join("storage", "screenshots", "screenshot_#{timestamp}.png").tap do |path|
        FileUtils.mkdir_p(File.dirname(path))
      end
    end

    def generate_pdf_path
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      Rails.root.join("tmp", "pdfs", "report_#{timestamp}.pdf").tap do |path|
        FileUtils.mkdir_p(File.dirname(path))
      end
    end

    def cleanup_temp_files
      # Clean up any temporary files if needed
      @temp_script&.unlink rescue nil
      @temp_script = nil
    end
  end
end
