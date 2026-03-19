# frozen_string_literal: true

# Per-tenant encryption key provider for ActiveRecord Encryption.
#
# Derives unique encryption keys per company using HKDF, preventing
# confused deputy attacks where encrypted data could be copied between
# tenants. Falls back to the global key for records encrypted before
# per-tenant keys were introduced.
#
# Supports key rotation: when primary_key is an array, the last key
# encrypts new data and all keys are tried for decryption (matching
# Rails' built-in rotation semantics).
#
# Usage:
#   encrypts :field, key_provider: Encryption::TenantKeyProvider.new
class Encryption::TenantKeyProvider
  def encryption_key
    tenant = ActsAsTenant.current_tenant

    unless tenant
      if Rails.env.production?
        Rails.logger.warn("Encryption without tenant context — using global key. " \
          "Wrap the operation in ActsAsTenant.with_tenant(company) { ... }")
      end
      return global_fallback_provider.encryption_key
    end

    derive_tenant_key(tenant.id, primary_master_key)
  end

  def decryption_keys(encrypted_message)
    tenant = ActsAsTenant.current_tenant
    keys = []
    if tenant
      all_master_keys.each { |mk| keys << derive_tenant_key(tenant.id, mk) }
    end
    keys.concat(global_fallback_provider.decryption_keys(encrypted_message))
    keys
  end

  private

  def derive_tenant_key(tenant_id, key)
    @tenant_keys ||= {}
    @tenant_keys[[ tenant_id, key ]] ||= ActiveRecord::Encryption::Key.new(
      OpenSSL::KDF.hkdf(
        key,
        salt: salt,
        info: "tenant-#{tenant_id}",
        length: 32,
        hash: "SHA256"
      )
    )
  end

  def global_fallback_provider
    @global_fallback_provider ||=
      ActiveRecord::Encryption::DerivedSecretKeyProvider.new(raw_primary_key)
  end

  # The newest key (last in the array) used for encryption.
  def primary_master_key
    all_master_keys.last
  end

  # All master keys for decryption (supports rotation arrays).
  def all_master_keys
    @all_master_keys ||= Array(raw_primary_key)
  end

  def raw_primary_key
    @raw_primary_key ||= Rails.application.config.active_record.encryption.primary_key ||
      raise("Missing active_record_encryption.primary_key — check config/initializers/active_record_encryption.rb")
  end

  def salt
    @salt ||= Rails.application.config.active_record.encryption.key_derivation_salt ||
      raise("Missing active_record_encryption.key_derivation_salt — check config/initializers/active_record_encryption.rb")
  end
end
