require "rails_helper"

RSpec.describe LocalhostDetector do
  describe ".localhost?" do
    context "with nil or empty host" do
      it "returns false for nil" do
        expect(described_class.localhost?(nil)).to be false
      end

      it "returns false for empty string" do
        expect(described_class.localhost?("")).to be false
      end
    end

    context "with standard localhost identifiers" do
      it "returns true for 'localhost'" do
        expect(described_class.localhost?("localhost")).to be true
      end

      it "returns true for '127.0.0.1'" do
        expect(described_class.localhost?("127.0.0.1")).to be true
      end

      it "returns true for IPv6 loopback '::1'" do
        expect(described_class.localhost?("::1")).to be true
      end
    end

    context "with 127.0.0.x IP range" do
      it "returns true for 127.0.0.0" do
        expect(described_class.localhost?("127.0.0.0")).to be true
      end

      it "returns true for 127.0.0.5" do
        expect(described_class.localhost?("127.0.0.5")).to be true
      end

      it "returns true for 127.0.0.100" do
        expect(described_class.localhost?("127.0.0.100")).to be true
      end

      it "returns true for 127.0.0.255" do
        expect(described_class.localhost?("127.0.0.255")).to be true
      end
    end

    context "with non-localhost addresses" do
      it "returns false for example.com" do
        expect(described_class.localhost?("example.com")).to be false
      end

      it "returns false for 192.168.1.1" do
        expect(described_class.localhost?("192.168.1.1")).to be false
      end

      it "returns false for 10.0.0.1" do
        expect(described_class.localhost?("10.0.0.1")).to be false
      end

      it "returns false for 172.16.0.1" do
        expect(described_class.localhost?("172.16.0.1")).to be false
      end

      it "returns false for google.com" do
        expect(described_class.localhost?("google.com")).to be false
      end
    end

    context "with edge cases" do
      it "returns false for 127.0.1.1 (different subnet)" do
        expect(described_class.localhost?("127.0.1.1")).to be false
      end

      it "returns false for 127.1.0.1 (different subnet)" do
        expect(described_class.localhost?("127.1.0.1")).to be false
      end

      it "returns true for 127.0.0.256 (regex matches despite invalid octet)" do
        # Note: The regex doesn't validate octet ranges, just checks pattern
        expect(described_class.localhost?("127.0.0.256")).to be true
      end

      it "returns false for 127.0.0.1000 (invalid octet)" do
        expect(described_class.localhost?("127.0.0.1000")).to be false
      end

      it "returns false for 127.0.0 (incomplete address)" do
        expect(described_class.localhost?("127.0.0")).to be false
      end

      it "returns false for 127.0.0.1.1 (too many octets)" do
        expect(described_class.localhost?("127.0.0.1.1")).to be false
      end
    end
  end
end
