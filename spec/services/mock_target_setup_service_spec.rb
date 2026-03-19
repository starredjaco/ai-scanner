require 'rails_helper'

RSpec.describe MockTargetSetupService do
  let!(:litmus_probe) { create(:probe, name: "LitmusTest", category: "0din") }
  let!(:other_probes) { create_list(:probe, 4, enabled: true) }

  describe ".call" do
    it "creates a mock target with correct configuration" do
      result = described_class.call

      expect(result[:target]).to be_a(Target)
      expect(result[:target].name).to eq("Mock LLM Test Target")
      expect(result[:target].model_type).to eq("RestGenerator")
      expect(result[:target].model).to eq("rest")

      config = JSON.parse(result[:target].json_config)
      expect(config["rest"]["RestGenerator"]["uri"]).to include("localhost:3000/api/v1/mock_llm/chat")
      expect(config["rest"]["RestGenerator"]["method"]).to eq("post")
    end

    it "creates a scan with probes" do
      result = described_class.call

      expect(result[:scan]).to be_a(Scan)
      expect(result[:scan].name).to eq("Mock LLM Basic Validation Scan")
      expect(result[:scan].probes.count).to be >= 1
      expect(result[:scan].targets).to include(result[:target])
    end

    it "creates and starts a report" do
      result = described_class.call

      expect(result[:report]).to be_a(Report)
      expect(result[:report].target).to eq(result[:target])
      expect(result[:report].scan).to eq(result[:scan])
      expect(result[:report].status).to eq("starting")
    end

    it "returns success message with report UUID" do
      result = described_class.call

      expect(result[:message]).to include("Mock LLM target created successfully")
      expect(result[:message]).to include(result[:report].uuid)
    end

    context "when target already exists" do
      let(:company) { Company.find_or_create_by!(name: "Mock LLM Testing Company") { |c| c.tier = :tier_4 } }
      let!(:existing_target) do
        create(:target,
               name: "Mock LLM Test Target",
               model_type: "RestGenerator",
               model: "rest",
               company: company,
               json_config: { "old" => "config" }.to_json)
      end

      it "updates existing target configuration" do
        result = described_class.call

        expect(result[:target]).to eq(existing_target.reload)

        config = JSON.parse(result[:target].json_config)
        expect(config["rest"]["RestGenerator"]["uri"]).to include("localhost:3000/api/v1/mock_llm/chat")
      end
    end

    context "when scan already exists" do
      let(:company) { Company.find_or_create_by!(name: "Mock LLM Testing Company") { |c| c.tier = :tier_4 } }
      let!(:existing_target) { create(:target, model_type: "RestGenerator", model: "rest", company: company) }
      let!(:existing_scan) { create(:complete_scan, name: "Mock LLM Basic Validation Scan", company: company) }

      it "uses existing scan" do
        result = described_class.call

        expect(result[:scan]).to eq(existing_scan)
      end
    end
  end

  describe "private methods" do
    let(:service) { described_class.new }

    describe "MOCK_TARGET_CONFIG" do
      it "contains correct REST generator configuration" do
        config = described_class::MOCK_TARGET_CONFIG

        expect(config["rest"]["RestGenerator"]["name"]).to eq("Mock LLM for Scanner Testing")
        expect(config["rest"]["RestGenerator"]["uri"]).to include("localhost:3000/api/v1/mock_llm/chat")
        expect(config["rest"]["RestGenerator"]["method"]).to eq("post")
        expect(config["rest"]["RestGenerator"]["response_json"]).to be true
        expect(config["rest"]["RestGenerator"]["response_json_field"]).to eq("text")
      end
    end
  end
end
