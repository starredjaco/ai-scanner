# frozen_string_literal: true

require "rails_helper"

RSpec.describe Encryption::TenantKeyProvider do
  subject(:provider) { described_class.new }

  describe "#encryption_key" do
    context "with tenant context" do
      let(:company) { create(:company) }

      it "returns a key derived from the tenant ID" do
        key = ActsAsTenant.with_tenant(company) { provider.encryption_key }
        expect(key).to be_a(ActiveRecord::Encryption::Key)
        expect(key.secret.bytesize).to eq(32)
      end
    end

    context "with different tenants" do
      let(:company_a) { create(:company) }
      let(:company_b) { create(:company) }

      it "produces different keys for different tenant IDs" do
        key_a = ActsAsTenant.with_tenant(company_a) { provider.encryption_key }
        key_b = ActsAsTenant.with_tenant(company_b) { provider.encryption_key }

        expect(key_a.secret).not_to eq(key_b.secret)
      end

      it "produces the same key for the same tenant ID" do
        key1 = ActsAsTenant.with_tenant(company_a) { provider.encryption_key }
        key2 = ActsAsTenant.with_tenant(company_a) { provider.encryption_key }

        expect(key1.secret).to eq(key2.secret)
      end
    end

    context "without tenant context" do
      it "falls back to the global key" do
        ActsAsTenant.without_tenant do
          key = provider.encryption_key
          expect(key).to be_a(ActiveRecord::Encryption::Key)
        end
      end
    end
  end

  describe "#decryption_keys" do
    let(:company) { create(:company) }
    let(:global_key) { ActiveRecord::Encryption::Key.new(SecureRandom.random_bytes(32)) }

    before do
      allow(provider).to receive(:global_fallback_provider).and_return(
        double(decryption_keys: [ global_key ])
      )
    end

    context "with tenant context" do
      it "returns tenant key followed by global fallback keys" do
        keys = ActsAsTenant.with_tenant(company) do
          provider.decryption_keys(nil)
        end

        expect(keys.length).to eq(2)
        expect(keys).to all(be_a(ActiveRecord::Encryption::Key))
      end

      it "includes the tenant-specific key first" do
        tenant_key = ActsAsTenant.with_tenant(company) { provider.encryption_key }
        decryption_keys = ActsAsTenant.with_tenant(company) do
          provider.decryption_keys(nil)
        end

        expect(decryption_keys.first.secret).to eq(tenant_key.secret)
      end
    end

    context "without tenant context" do
      it "returns only global fallback keys" do
        keys = ActsAsTenant.without_tenant do
          provider.decryption_keys(nil)
        end

        expect(keys).to all(be_a(ActiveRecord::Encryption::Key))
        expect(keys.length).to eq(1)
      end
    end
  end
end
