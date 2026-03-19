require "rails_helper"

RSpec.describe OutputServers::Dispatcher do
  let(:target) { create(:target) }
  let(:probe) { create(:probe) }
  let(:scan) { create(:scan, targets: [ target ], probes: [ probe ], output_server: output_server) }
  let(:report) { create(:report, target: target, scan: scan) }
  let(:dispatcher) { described_class.new(report) }

  before do
    # Stub background jobs to prevent execution
    allow(ValidateTargetJob).to receive(:perform_later)
  end

  describe "#call" do
    context "when output server is nil" do
      let(:output_server) { nil }

      it "returns without calling any service" do
        expect(OutputServers::Splunk).not_to receive(:new)
        expect(OutputServers::Rsyslog).not_to receive(:new)

        dispatcher.call
      end
    end

    context "when output server is disabled" do
      let(:output_server) { create(:output_server, enabled: false) }

      it "returns without calling any service" do
        expect(OutputServers::Splunk).not_to receive(:new)
        expect(OutputServers::Rsyslog).not_to receive(:new)

        dispatcher.call
      end
    end

    context "when output server type is splunk" do
      let(:output_server) { create(:output_server, server_type: "splunk", enabled: true) }
      let(:splunk_service) { instance_double(OutputServers::Splunk) }

      it "calls the Splunk service" do
        expect(OutputServers::Splunk).to receive(:new).with(report).and_return(splunk_service)
        expect(splunk_service).to receive(:call)

        dispatcher.call
      end
    end

    context "when output server type is rsyslog" do
      let(:output_server) { create(:output_server, server_type: "rsyslog", enabled: true) }
      let(:rsyslog_service) { instance_double(OutputServers::Rsyslog) }

      it "calls the Rsyslog service" do
        expect(OutputServers::Rsyslog).to receive(:new).with(report).and_return(rsyslog_service)
        expect(rsyslog_service).to receive(:call)

        dispatcher.call
      end
    end

    context "when output server type is unsupported" do
      let(:output_server) { create(:output_server, enabled: true) }

      before do
        allow(output_server).to receive(:server_type).and_return("unsupported_type")
      end

      it "logs an error and returns" do
        expect(Rails.logger).to receive(:error).with("Unsupported output server type: unsupported_type")
        expect(OutputServers::Splunk).not_to receive(:new)
        expect(OutputServers::Rsyslog).not_to receive(:new)

        dispatcher.call
      end
    end

    context "when service raises an exception" do
      let(:output_server) { create(:output_server, server_type: "splunk", enabled: true) }
      let(:splunk_service) { instance_double(OutputServers::Splunk) }

      it "logs the error" do
        expect(OutputServers::Splunk).to receive(:new).with(report).and_return(splunk_service)
        expect(splunk_service).to receive(:call).and_raise(StandardError, "Connection failed")

        expect(Rails.logger).to receive(:error).with("Failed to dispatch to output server: Connection failed")
        expect(Rails.logger).to receive(:error).with(anything) # For backtrace

        dispatcher.call
      end
    end
  end
end
