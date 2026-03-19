require 'rails_helper'
require 'logging'

RSpec.describe ValidateTargetJob, type: :job do
  describe '#perform' do
    let(:target) { create(:target) }
    let(:validate_service) { instance_double(ValidateTarget) }
    let(:logger) { instance_double(ActiveSupport::Logger) }

    before do
      allow(ValidateTarget).to receive(:new).with(target).and_return(validate_service)
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    context 'when the target exists and validation succeeds' do
      before do
        allow(validate_service).to receive(:call)
      end

      it 'calls the ValidateTarget service' do
        expect(ValidateTarget).to receive(:new).with(target).and_return(validate_service)
        expect(validate_service).to receive(:call)

        described_class.new.perform(target.id)
      end

      it 'logs job start and finish with context' do
        expect(logger).to receive(:info).with("validation.job.started")
        expect(logger).to receive(:info).with("validation.job.finished")

        described_class.new.perform(target.id)
      end
    end

    context 'when the target does not exist' do
      let(:non_existent_id) { 99999 }

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error and does not raise an exception' do
        expect(logger).to receive(:error).with("validation.job.target_not_found")

        expect { described_class.new.perform(non_existent_id) }.not_to raise_error
      end

      it 'does not call the ValidateTarget service' do
        expect(ValidateTarget).not_to receive(:new)

        described_class.new.perform(non_existent_id)
      end
    end

    context 'when the validation service raises an error' do
      let(:error_message) { 'Validation service failed' }
      let(:error) { StandardError.new(error_message) }

      before do
        allow(validate_service).to receive(:call).and_raise(error)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with("validation.job.failed")

        described_class.new.perform(target.id)
      end

      it 'updates the target status to bad with error message' do
        expect {
          described_class.new.perform(target.id)
        }.to change { target.reload.status }.to('bad')

        expect(target.reload.validation_text).to eq("Validation job failed: #{error_message}")
      end

      it 'does not raise the error' do
        expect { described_class.new.perform(target.id) }.not_to raise_error
      end
    end

    context 'when the validation service raises an error and target is deleted during error handling' do
      let(:error_message) { 'Validation service failed' }
      let(:error) { StandardError.new(error_message) }

      before do
        allow(validate_service).to receive(:call).and_raise(error)
        allow(Rails.logger).to receive(:error)
        # First call to find succeeds (to create the service), second call fails (during error handling)
        call_count = 0
        allow(Target).to receive(:find).with(target.id) do
          call_count += 1
          if call_count == 1
            target
          else
            raise ActiveRecord::RecordNotFound
          end
        end
      end

      it 'logs the validation error but does not crash when trying to update deleted target' do
        expect(logger).to receive(:error).with("validation.job.failed")

        expect { described_class.new.perform(target.id) }.not_to raise_error
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on the default queue' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'inherits from ApplicationJob' do
      expect(described_class.superclass).to eq(ApplicationJob)
    end
  end

  describe 'tenant context' do
    let(:target) { create(:target) }
    let(:validate_service) { instance_double(ValidateTarget) }
    let(:logger) { instance_double(ActiveSupport::Logger) }

    before do
      allow(ValidateTarget).to receive(:new).with(target).and_return(validate_service)
      allow(validate_service).to receive(:call)
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    it 'sets tenant context to the target company before calling ValidateTarget' do
      tenant_during_call = nil
      allow(validate_service).to receive(:call) do
        tenant_during_call = ActsAsTenant.current_tenant
      end

      described_class.new.perform(target.id)

      expect(tenant_during_call).to eq(target.company)
    end

    it 'sets tenant context during error handling target update' do
      allow(validate_service).to receive(:call).and_raise(StandardError, "boom")

      described_class.new.perform(target.id)

      target.reload
      expect(target.status).to eq("bad")
      expect(target.validation_text).to include("boom")
    end
  end

  describe 'integration test' do
    let(:target) { create(:target, status: :validating) }

    before do
      # Mock the ValidateTarget service to avoid actual garak execution
      allow_any_instance_of(ValidateTarget).to receive(:call) do |service|
        service.target.update(status: :good, validation_text: 'Target validated successfully')
      end
    end

    it 'processes the validation successfully' do
      expect {
        described_class.new.perform(target.id)
      }.to change { target.reload.status }.from('validating').to('good')

      expect(target.reload.validation_text).to eq('Target validated successfully')
    end
  end
end
