# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    ActsAsTenant.current_tenant = nil
  end
end
