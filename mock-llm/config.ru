# Rackup configuration for standalone Mock LLM server
# Run with: rackup -p PORT
# Example: rackup -p 9292

require_relative "app"

# Enable logging
use Rack::CommonLogger

# Run the app
run MockLlmRackApp.new
