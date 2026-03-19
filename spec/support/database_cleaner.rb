# Use Rails' built-in transactional fixtures for multi-database setup
RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
