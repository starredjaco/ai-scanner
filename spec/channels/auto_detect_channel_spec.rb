require "rails_helper"

RSpec.describe AutoDetectChannel, type: :channel do
  # Use build_stubbed to avoid database operations
  let!(:user) { build_stubbed(:user, id: 1) }
  let(:uuid) { SecureRandom.uuid }
  let(:verifier) { Rails.application.message_verifier(:auto_detect_session) }
  let(:valid_session_id) { verifier.generate([ user.id, uuid ]) }
  let(:invalid_session_id) { "invalid-signature-123" }
  let(:tampered_session_id) { verifier.generate([ 999, uuid ]) }  # Different user ID

  before do
    stub_connection(current_user: user)
  end

  describe "#subscribed" do
    context "with valid session_id" do
      it "successfully subscribes to the stream" do
        subscribe(session_id: valid_session_id)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("auto_detect_#{valid_session_id}")
      end

      it "logs successful subscription" do
        expect(Rails.logger).to receive(:info).with(include("AutoDetectChannel subscribed"))

        subscribe(session_id: valid_session_id)
      end
    end

    context "with invalid session_id" do
      it "rejects subscription with invalid signature" do
        subscribe(session_id: invalid_session_id)

        expect(subscription).to be_rejected
      end
    end

    context "with blank session_id" do
      it "rejects subscription" do
        subscribe(session_id: "")

        expect(subscription).to be_rejected
      end

      it "rejects subscription with nil session_id" do
        subscribe(session_id: nil)

        expect(subscription).to be_rejected
      end
    end

    context "with session_id for different user" do
      it "rejects subscription" do
        subscribe(session_id: tampered_session_id)

        expect(subscription).to be_rejected
      end

      it "logs unauthorized attempt" do
        expect(Rails.logger).to receive(:warn).with(include("Unauthorized subscription attempt"))

        subscribe(session_id: tampered_session_id)
      end
    end
  end

  describe "#unsubscribed" do
    before do
      subscribe(session_id: valid_session_id)
    end

    it "stops all streams" do
      expect(subscription).to have_stream_from("auto_detect_#{valid_session_id}")

      unsubscribe

      expect(subscription).not_to have_streams
    end

    it "logs unsubscription" do
      expect(Rails.logger).to receive(:info).with(include("AutoDetectChannel unsubscribed"))

      unsubscribe
    end
  end
end
