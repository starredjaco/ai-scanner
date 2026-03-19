RSpec.shared_context "mocked logger" do
  let(:logger) { instance_double(ActiveSupport::Logger) }
  let(:logged_messages) { [] }
  let(:logged_contexts) { [] }

  before do
    allow(Rails).to receive(:logger).and_return(logger)

    [ :info, :error, :warn, :debug ].each do |level|
      allow(logger).to receive(level) do |message|
        logged_messages << { level: level, message: message }
        logged_contexts << Logging.context.dup
        message
      end
    end
  end
end
