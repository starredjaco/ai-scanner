require "rails_helper"

RSpec.describe RawReportData, type: :model do
  describe "associations" do
    it { should belong_to(:report) }
  end

  describe "validations" do
    subject { build(:raw_report_data) }

    it { should validate_presence_of(:report_id) }
    it { should validate_uniqueness_of(:report_id) }
    it { should validate_presence_of(:jsonl_data) }
    it { should validate_presence_of(:status) }
  end

  describe "enum" do
    it { should define_enum_for(:status).with_values(pending: 0, processing: 1) }
  end

  describe "#mark_processing!" do
    let(:raw_data) { create(:raw_report_data, status: :pending) }

    it "updates status to processing" do
      expect { raw_data.mark_processing! }.to change { raw_data.reload.status }.from("pending").to("processing")
    end
  end

  describe "#each_jsonl_line" do
    context "with valid JSONL data" do
      let(:raw_data) do
        create(:raw_report_data, jsonl_data: <<~JSONL)
          {"entry_type": "init", "start_time": "2023-01-01T00:00:00Z"}
          {"entry_type": "attempt", "probe_classname": "test.Probe"}
          {"entry_type": "completion", "end_time": "2023-01-01T01:00:00Z"}
        JSONL
      end

      it "yields each parsed JSON line" do
        lines = raw_data.each_jsonl_line.to_a
        expect(lines.size).to eq(3)
        expect(lines[0]["entry_type"]).to eq("init")
        expect(lines[1]["entry_type"]).to eq("attempt")
        expect(lines[2]["entry_type"]).to eq("completion")
      end
    end

    context "with empty lines" do
      let(:raw_data) do
        create(:raw_report_data, jsonl_data: <<~JSONL)
          {"entry_type": "init"}

          {"entry_type": "completion"}
        JSONL
      end

      it "skips empty lines" do
        lines = raw_data.each_jsonl_line.to_a
        expect(lines.size).to eq(2)
      end
    end

    context "with whitespace-only lines" do
      let(:raw_data) do
        create(:raw_report_data, jsonl_data: "  \n{\"entry_type\": \"init\"}\n\t\n")
      end

      it "skips whitespace-only lines" do
        lines = raw_data.each_jsonl_line.to_a
        expect(lines.size).to eq(1)
      end
    end

    context "with invalid JSON" do
      let(:raw_data) do
        create(:raw_report_data, jsonl_data: <<~JSONL)
          {"entry_type": "init"}
          not valid json
          {"entry_type": "completion"}
        JSONL
      end

      it "logs warning and skips invalid lines" do
        expect(Rails.logger).to receive(:warn).with(/JSON parse error/)
        lines = raw_data.each_jsonl_line.to_a
        expect(lines.size).to eq(2)
      end
    end

    context "without block" do
      let(:raw_data) { create(:raw_report_data, jsonl_data: '{"test": 1}') }

      it "returns an Enumerator" do
        expect(raw_data.each_jsonl_line).to be_an(Enumerator)
      end
    end
  end
end
