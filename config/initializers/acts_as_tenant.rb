# frozen_string_literal: true

ActsAsTenant.configure do |config|
  # Don't require tenant to be set for all queries.
  # This allows:
  # - Background jobs to process data across tenants
  # - Development environment with auth bypass
  # - Tests to create records without setting tenant
  # - Super admin features (future) to access cross-tenant data
  config.require_tenant = false
end
