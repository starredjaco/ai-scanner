require 'rails_helper'

RSpec.describe OutputServer, type: :model do
  describe 'validations' do
    subject { build(:output_server) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:company_id) }
    it { is_expected.to validate_presence_of(:server_type) }
    it { is_expected.to validate_numericality_of(:port).only_integer.is_greater_than(0).is_less_than_or_equal_to(65535).allow_nil }

    it 'validates server_type inclusion in SIEM_TYPES' do
      expect(OutputServer::SIEM_TYPES).to include('splunk', 'rsyslog')

      valid_server = build(:output_server, server_type: 'splunk')
      expect(valid_server).to be_valid

      server_type_validators = OutputServer.validators_on(:server_type)
      inclusion_validator = server_type_validators.find { |v| v.is_a?(ActiveModel::Validations::InclusionValidator) }
      expect(inclusion_validator).to be_present
      expect(inclusion_validator.options[:message]).to eq("%{value} is not a supported SIEM type")
    end

    it 'validates protocol inclusion' do
      valid_server = build(:output_server, protocol: 'https')
      expect(valid_server).to be_valid

      protocol_validators = OutputServer.validators_on(:protocol)
      inclusion_validator = protocol_validators.find { |v| v.is_a?(ActiveModel::Validations::InclusionValidator) }
      expect(inclusion_validator).to be_present
      expect(inclusion_validator.options[:in]).to match_array(%w[http https udp tcp tls])
      expect(inclusion_validator.options[:message]).to eq("%{value} is not a valid protocol")

      expect(OutputServer.protocols.keys).to match_array(%w[http https udp tcp tls])
    end

    it 'defines server_type enum with all known types for DB compatibility' do
      expect(OutputServer.server_types.keys).to include('splunk', 'rsyslog')
    end

    it 'exposes available_server_types for validation' do
      expect(OutputServer.available_server_types).to include('splunk', 'rsyslog')
    end

    it 'defines protocol enum correctly' do
      expect(OutputServer.protocols.keys).to match_array(%w[http https udp tcp tls])
    end
  end

  describe 'additional_settings validation' do
    it 'allows valid JSON' do
      server = build(:output_server, additional_settings: '{"key": "value"}')
      expect(server).to be_valid
    end

    it 'rejects invalid JSON' do
      output_server = build(:output_server, additional_settings: "not json")
      expect(output_server).to_not be_valid
      expect(output_server.errors[:additional_settings]).to include(a_string_matching(/must be valid JSON/))
    end
  end

  describe '.ransackable_attributes' do
    it 'returns only safe searchable attributes' do
      expect(OutputServer.ransackable_attributes).to match_array(%w[
        company_id created_at description enabled endpoint_path host id name port protocol server_type updated_at
      ])
    end

    it 'does not expose sensitive credential fields' do
      sensitive_fields = %w[access_token api_key password username additional_settings]
      expect(OutputServer.ransackable_attributes & sensitive_fields).to be_empty
    end
  end

  describe 'instance methods' do
    let(:server) { build(:output_server, host: 'test.example.com', port: 8089, endpoint_path: '/api/endpoint') }

    describe '#connection_string' do
      it 'returns a properly formatted connection string' do
        expect(server.connection_string).to eq('https://test.example.com:8089/api/endpoint')
      end
    end

    describe '#authentication_method' do
      it 'returns :token when access_token is present' do
        server.access_token = 'token123'
        expect(server.authentication_method).to eq(:token)
      end

      it 'returns :api_key when api_key is present' do
        server.api_key = 'apikey123'
        expect(server.authentication_method).to eq(:api_key)
      end

      it 'returns :basic when username and password are present' do
        server.username = 'user'
        server.password = 'pass'
        expect(server.authentication_method).to eq(:basic)
      end

      it 'returns :none when no authentication credentials are present' do
        server.access_token = nil
        server.api_key = nil
        server.username = nil
        server.password = nil
        expect(server.authentication_method).to eq(:none)
      end
    end
  end
end
