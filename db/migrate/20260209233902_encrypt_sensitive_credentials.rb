# frozen_string_literal: true

# Encrypts sensitive credential fields at rest using Rails ActiveRecord Encryption
# with per-tenant key isolation.
#
# Phase 1: Changes column types from json/string to text (encrypted payloads are
#           strings, not valid JSON).
# Phase 2: Fixes double-encoded JSON from the old json column type.
# Phase 3: Encrypts existing records with per-tenant derived keys using
#           Encryption::TenantKeyProvider (HKDF from master key + company_id).
#
# The `encrypts` declarations on Target and EnvironmentVariable models handle
# transparent encryption/decryption going forward.
class EncryptSensitiveCredentials < ActiveRecord::Migration[8.0]
  def up
    # Phase 1: Change column types to text for encrypted storage
    change_column :targets, :json_config, :text
    change_column :targets, :web_config, :text
    change_column :environment_variables, :env_value, :text, null: false

    # Phase 2: Fix double-encoded JSON from the old json column.
    # When forms submitted JSON as a string to a json column, PostgreSQL stored it
    # as a JSON string value (e.g., '"{\\"url\\": ...}"') rather than a JSON object.
    # The json column's type cast auto-unwrapped this, but text columns don't.
    # Unwrap before encrypting so the data is clean going forward.
    say_with_time "Fixing double-encoded JSON in target configs" do
      count = 0
      ActsAsTenant.without_tenant do
        Target.unscope(where: :deleted_at).in_batches(of: 100) do |batch|
          batch.each do |target|
            updates = {}
            %i[json_config web_config].each do |field|
              raw = target.read_attribute_before_type_cast(field)
              next if raw.blank?
              begin
                parsed = JSON.parse(raw)
              rescue JSON::ParserError => e
                say "WARNING: Skipping #{field} for target #{target.id} - invalid JSON: #{e.message}"
                next
              end
              if parsed.is_a?(String)
                updates[field] = parsed
              end
            end
            if updates.any?
              Target.unscope(where: :deleted_at).where(id: target.id).update_all(updates)
              count += 1
            end
          end
        end
      end
      count
    end

    # Phase 3: Encrypt existing records with per-tenant derived keys.
    # Uses target.encrypt (Rails built-in) which bypasses dirty tracking and
    # forces re-encryption via update_columns. Each record is encrypted within
    # its tenant context so the TenantKeyProvider derives the correct key.
    say_with_time "Encrypting targets with per-tenant keys" do
      count = 0
      failures = []
      ActsAsTenant.without_tenant do
        Target.unscope(where: :deleted_at).in_batches(of: 100) do |batch|
          batch.each do |target|
            next unless target.json_config.present? || target.web_config.present?
            ActsAsTenant.with_tenant(target.company) do
              target.encrypt
            end
            count += 1
          rescue StandardError => e
            failures << { id: target.id, error: e.message }
            say "Failed to encrypt target #{target.id}: #{e.message}"
          end
        end
      end
      raise "Failed to encrypt #{failures.size} target(s): #{failures.inspect}" if failures.any?
      count
    end

    say_with_time "Encrypting environment variables with per-tenant keys" do
      count = 0
      failures = []
      ActsAsTenant.without_tenant do
        EnvironmentVariable.in_batches(of: 100) do |batch|
          batch.each do |env_var|
            ActsAsTenant.with_tenant(env_var.company) do
              env_var.encrypt
            end
            count += 1
          rescue StandardError => e
            failures << { id: env_var.id, error: e.message }
            say "Failed to encrypt env var #{env_var.id}: #{e.message}"
          end
        end
      end
      raise "Failed to encrypt #{failures.size} environment variable(s): #{failures.inspect}" if failures.any?
      count
    end
  end

  def down
    # Verify encryption declarations still exist on models before attempting rollback.
    # Without them, AR cannot decrypt data and rollback would cause permanent data loss.
    unless Target.encrypted_attributes&.include?(:json_config)
      raise "Cannot rollback: Target model must still have 'encrypts' declarations. " \
            "Restore model code first, then rollback migration. See config/initializers/active_record_encryption.rb."
    end
    unless EnvironmentVariable.encrypted_attributes&.include?(:env_value)
      raise "Cannot rollback: EnvironmentVariable model must still have 'encrypts :env_value'. " \
            "Restore model code first, then rollback migration. See config/initializers/active_record_encryption.rb."
    end

    # Decrypt all records by reading through AR (which decrypts via TenantKeyProvider)
    # and writing plaintext via update_all (which bypasses AR encryption).
    ActsAsTenant.without_tenant do
      say_with_time "Decrypting target configurations" do
        count = 0
        failures = []
        Target.unscope(where: :deleted_at).find_each do |target|
          updates = {}
          ActsAsTenant.with_tenant(target.company) do
            updates[:json_config] = target.json_config if target.json_config.present?
            updates[:web_config] = target.web_config if target.web_config.present?
          end
          if updates.any?
            Target.unscope(where: :deleted_at).where(id: target.id).update_all(updates)
            count += 1
          end
        rescue StandardError => e
          failures << { id: target.id, error: e.message }
          say "Failed to decrypt target #{target.id}: #{e.message}"
        end
        raise "Failed to decrypt #{failures.size} target(s): #{failures.inspect}" if failures.any?
        count
      end

      say_with_time "Decrypting environment variable values" do
        count = 0
        failures = []
        EnvironmentVariable.find_each do |env_var|
          plaintext = ActsAsTenant.with_tenant(env_var.company) { env_var.env_value }
          EnvironmentVariable.where(id: env_var.id).update_all(env_value: plaintext)
          count += 1
        rescue StandardError => e
          failures << { id: env_var.id, error: e.message }
          say "Failed to decrypt environment_variable #{env_var.id}: #{e.message}"
        end
        raise "Failed to decrypt #{failures.size} environment variable(s): #{failures.inspect}" if failures.any?
        count
      end
    end

    # Clean up empty strings before casting back to json (empty string is not valid JSON)
    Target.unscope(where: :deleted_at).where(json_config: "").update_all(json_config: nil)
    Target.unscope(where: :deleted_at).where(web_config: "").update_all(web_config: nil)

    # Revert column types
    change_column :targets, :json_config, :json, using: "json_config::json"
    change_column :targets, :web_config, :json, using: "web_config::json"
    change_column :environment_variables, :env_value, :string, null: false
  end
end
