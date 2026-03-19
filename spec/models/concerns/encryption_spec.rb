# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ActiveRecord Encryption", type: :model do
  describe "Target encrypted fields" do
    it "encrypts json_config at rest" do
      target = create(:target, :with_json_config)
      raw = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT json_config FROM targets WHERE id = ?", target.id ])
      )
      expect(raw).not_to eq(target.json_config)
    end

    it "decrypts json_config transparently" do
      target = create(:target, json_config: '{"key": "value"}')
      target.reload
      expect(target.json_config).to eq('{"key": "value"}')
    end

    it "handles nil json_config" do
      target = create(:target, json_config: nil)
      target.reload
      expect(target.json_config).to be_nil
    end

    it "encrypts web_config at rest" do
      config = {
        "url" => "https://example.com/chat",
        "selectors" => {
          "input_field" => "#input",
          "response_container" => "#response"
        }
      }
      target = create(:target, target_type: :webchat, web_config: config)
      raw = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT web_config FROM targets WHERE id = ?", target.id ])
      )
      expect(raw).not_to eq(config.to_json)
    end

    it "decrypts web_config transparently" do
      config = {
        "url" => "https://example.com/chat",
        "selectors" => {
          "input_field" => "#input",
          "response_container" => "#response"
        }
      }
      target = create(:target, target_type: :webchat, web_config: config)
      target.reload
      expect(JSON.parse(target.web_config)).to eq(config)
    end

    it "handles nil web_config" do
      target = create(:target, web_config: nil)
      target.reload
      expect(target.web_config).to be_nil
    end

    it "normalizes Hash web_config to JSON string" do
      config = { "url" => "https://example.com" }
      target = build(:target, web_config: config)
      expect(target.web_config).to be_a(String)
      expect(JSON.parse(target.web_config)).to eq(config)
    end

    it "normalizes Hash json_config to JSON string" do
      config = { "temperature" => 0.7 }
      target = build(:target, json_config: config)
      expect(target.json_config).to be_a(String)
      expect(JSON.parse(target.json_config)).to eq(config)
    end
  end

  describe "EnvironmentVariable encrypted fields" do
    it "encrypts env_value at rest" do
      ev = create(:environment_variable, env_value: "super_secret_key_123")
      raw = EnvironmentVariable.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT env_value FROM environment_variables WHERE id = ?", ev.id ])
      )
      expect(raw).not_to eq("super_secret_key_123")
    end

    it "decrypts env_value transparently" do
      ev = create(:environment_variable, env_value: "my_api_key")
      ev.reload
      expect(ev.env_value).to eq("my_api_key")
    end
  end

  describe "EnvironmentVariable per-tenant key isolation" do
    let(:company_a) { create(:company) }
    let(:company_b) { create(:company) }

    it "produces different ciphertext for different tenants" do
      ev_a = ActsAsTenant.with_tenant(company_a) { create(:environment_variable, env_value: "same_secret") }
      ev_b = ActsAsTenant.with_tenant(company_b) { create(:environment_variable, env_value: "same_secret") }

      raw_a = EnvironmentVariable.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT env_value FROM environment_variables WHERE id = ?", ev_a.id ])
      )
      raw_b = EnvironmentVariable.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT env_value FROM environment_variables WHERE id = ?", ev_b.id ])
      )

      expect(raw_a).not_to eq(raw_b)
    end

    it "decrypts correctly with the right tenant context" do
      ev = ActsAsTenant.with_tenant(company_a) { create(:environment_variable, env_value: "tenant_a_secret") }

      decrypted = ActsAsTenant.with_tenant(company_a) do
        EnvironmentVariable.find(ev.id).env_value
      end

      expect(decrypted).to eq("tenant_a_secret")
    end
  end

  describe "Target per-tenant key isolation" do
    let(:company_a) { create(:company) }
    let(:company_b) { create(:company) }

    it "produces different ciphertext for different tenants" do
      target_a = ActsAsTenant.with_tenant(company_a) { create(:target, json_config: '{"key": "same_value"}') }
      target_b = ActsAsTenant.with_tenant(company_b) { create(:target, json_config: '{"key": "same_value"}') }

      raw_a = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT json_config FROM targets WHERE id = ?", target_a.id ])
      )
      raw_b = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT json_config FROM targets WHERE id = ?", target_b.id ])
      )

      # Different tenants produce different ciphertext even for identical plaintext
      expect(raw_a).not_to eq(raw_b)
    end

    it "decrypts correctly with the right tenant context" do
      target = ActsAsTenant.with_tenant(company_a) { create(:target, json_config: '{"secret": "data"}') }

      decrypted = ActsAsTenant.with_tenant(company_a) do
        Target.find(target.id).json_config
      end

      expect(decrypted).to eq('{"secret": "data"}')
    end

    it "prevents confused deputy attack — wrong tenant cannot decrypt copied ciphertext" do
      # Encrypt with tenant A
      target_a = ActsAsTenant.with_tenant(company_a) { create(:target, json_config: '{"api_key": "secret"}') }

      # Copy raw ciphertext to a new target owned by tenant B
      raw_ciphertext = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT json_config FROM targets WHERE id = ?", target_a.id ])
      )
      target_b = ActsAsTenant.with_tenant(company_b) { create(:target) }
      Target.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(
          [ "UPDATE targets SET json_config = ? WHERE id = ?", raw_ciphertext, target_b.id ]
        )
      )

      # Tenant B should NOT be able to decrypt tenant A's data
      result = ActsAsTenant.with_tenant(company_b) do
        Target.find(target_b.id).json_config
      end

      # The decrypted value should NOT match the original plaintext
      # (it will either be nil, garbled, or fall back to the global key decryption)
      expect(result).not_to eq('{"api_key": "secret"}')
    end

    it "re-encrypts records when tenant context changes" do
      # Create without tenant (uses global key fallback)
      target = create(:target, json_config: '{"key": "value"}')
      raw_before = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT json_config FROM targets WHERE id = ?", target.id ])
      )

      # Re-encrypt with tenant context using Rails' built-in encrypt method
      # (save! won't re-encrypt because dirty tracking compares plaintext)
      ActsAsTenant.with_tenant(target.company) do
        target.encrypt
      end
      raw_after = Target.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT json_config FROM targets WHERE id = ?", target.id ])
      )

      # Ciphertext should differ (different key used)
      expect(raw_after).not_to eq(raw_before)

      # Should still decrypt correctly with tenant
      decrypted = ActsAsTenant.with_tenant(target.company) do
        Target.find(target.id).json_config
      end
      expect(decrypted).to eq('{"key": "value"}')
    end
  end
end
