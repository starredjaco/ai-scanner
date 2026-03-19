require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  describe "#connect" do
    context "with valid Warden session" do
      it "successfully connects" do
        warden = instance_double("Warden::Proxy")
        allow(warden).to receive(:user).with(:user).and_return(user)

        connect "/cable", env: { "warden" => warden }

        expect(connection.current_user).to eq(user)
      end
    end

    context "without authentication" do
      it "rejects connection when no Warden session" do
        expect {
          connect "/cable"
        }.to have_rejected_connection
      end

      it "rejects connection when Warden returns nil" do
        warden = instance_double("Warden::Proxy")
        allow(warden).to receive(:user).with(:user).and_return(nil)

        expect {
          connect "/cable", env: { "warden" => warden }
        }.to have_rejected_connection
      end
    end
  end
end
