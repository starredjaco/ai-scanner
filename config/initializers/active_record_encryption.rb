# frozen_string_literal: true

# ActiveRecord Encryption key configuration.
#
# Production: keys are derived deterministically from SECRET_KEY_BASE.
# Development/Test: use fixed keys so encryption works without credentials.
# Docker build (SECRET_KEY_BASE_DUMMY): use dummy keys for asset precompilation.

if Rails.env.test? || Rails.env.development?
  Rails.application.config.active_record.encryption.primary_key = "dev-primary-key-that-is-32-bytes"
  Rails.application.config.active_record.encryption.key_derivation_salt = "dev-key-derivation-salt-32-bytes"
else
  secret = ENV["SECRET_KEY_BASE"]

  if secret.present?
    primary_key = OpenSSL::HMAC.hexdigest("SHA256", secret, "active_record_encryption_primary_key")[0, 32]
    salt = OpenSSL::HMAC.hexdigest("SHA256", secret, "active_record_encryption_salt")[0, 32]
  elsif ENV["SECRET_KEY_BASE_DUMMY"].present?
    # Docker build asset precompilation — no real keys needed
    primary_key = "dummy-primary-key-for-precompile"
    salt = "dummy-salt-for-asset-precompile!"
  else
    raise "SECRET_KEY_BASE is required in production. " \
          "Generate one with: openssl rand -hex 64"
  end

  Rails.application.config.active_record.encryption.primary_key = primary_key
  Rails.application.config.active_record.encryption.key_derivation_salt = salt
end
