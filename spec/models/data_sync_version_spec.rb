require "rails_helper"

RSpec.describe DataSyncVersion, type: :model do
  describe "validations" do
    it { should validate_presence_of(:sync_type) }
    it { should validate_presence_of(:file_path) }
    it { should validate_presence_of(:file_checksum) }
  end

  describe "scopes" do
    let!(:probes_version1) { create(:data_sync_version, sync_type: "probes") }
    let!(:probes_version2) { create(:data_sync_version, sync_type: "probes") }
    let!(:detectors_version) { create(:data_sync_version, sync_type: "detectors") }

    describe ".for_type" do
      it "returns versions for specific sync type" do
        expect(DataSyncVersion.for_type("probes")).to contain_exactly(probes_version1, probes_version2)
        expect(DataSyncVersion.for_type("detectors")).to contain_exactly(detectors_version)
      end
    end

    describe ".latest_for_type" do
      it "returns the most recent version for a sync type" do
        expect(DataSyncVersion.latest_for_type("probes")).to eq(probes_version2)
        expect(DataSyncVersion.latest_for_type("detectors")).to eq(detectors_version)
      end

      it "returns nil for non-existent sync type" do
        expect(DataSyncVersion.latest_for_type("nonexistent")).to be_nil
      end
    end
  end

  describe ".needs_sync?" do
    let(:file_path) { "spec/fixtures/test_file.json" }
    let(:sync_type) { "test" }

    before do
      # Create a test file
      FileUtils.mkdir_p(File.dirname(Rails.root.join(file_path)))
      File.write(Rails.root.join(file_path), '{"test": "data"}')
    end

    after do
      File.delete(Rails.root.join(file_path)) if File.exist?(Rails.root.join(file_path))
    end

    context "when no previous version exists" do
      it "returns true" do
        expect(DataSyncVersion.needs_sync?(sync_type, file_path)).to be true
      end
    end

    context "when previous version exists with same checksum" do
      before do
        current_checksum = DataSyncVersion.send(:calculate_checksum, file_path)
        create(:data_sync_version,
               sync_type: sync_type,
               file_path: file_path,
               file_checksum: current_checksum)
      end

      it "returns false" do
        expect(DataSyncVersion.needs_sync?(sync_type, file_path)).to be false
      end
    end

    context "when previous version exists with different checksum" do
      before do
        create(:data_sync_version,
               sync_type: sync_type,
               file_path: file_path,
               file_checksum: "different_checksum")
      end

      it "returns true" do
        expect(DataSyncVersion.needs_sync?(sync_type, file_path)).to be true
      end
    end

    context "when table doesn't exist" do
      before do
        allow(DataSyncVersion).to receive(:table_exists?).and_return(false)
      end

      it "returns true" do
        expect(DataSyncVersion.needs_sync?(sync_type, file_path)).to be true
      end
    end
  end

  describe ".record_sync" do
    let(:file_path) { "spec/fixtures/test_file.json" }
    let(:sync_type) { "test" }
    let(:record_count) { 42 }
    let(:metadata) { { "foo" => "bar" } }

    before do
      # Create a test file
      FileUtils.mkdir_p(File.dirname(Rails.root.join(file_path)))
      File.write(Rails.root.join(file_path), '{"test": "data"}')
    end

    after do
      File.delete(Rails.root.join(file_path)) if File.exist?(Rails.root.join(file_path))
    end

    it "creates a new version record" do
      expect {
        DataSyncVersion.record_sync(sync_type, file_path, record_count, metadata)
      }.to change(DataSyncVersion, :count).by(1)

      version = DataSyncVersion.last
      expect(version.sync_type).to eq(sync_type)
      expect(version.file_path).to eq(file_path)
      expect(version.record_count).to eq(record_count)
      expect(version.metadata).to eq(metadata)
      expect(version.synced_at).to be_within(1.second).of(Time.current)
      expect(version.file_checksum).to be_present
    end

    context "when a record with the same checksum already exists" do
      it "updates the existing record instead of creating a new one" do
        DataSyncVersion.record_sync(sync_type, file_path, record_count, { "note" => "first" })

        expect {
          DataSyncVersion.record_sync(sync_type, file_path, 999, { "note" => "second" })
        }.not_to change(DataSyncVersion, :count)

        version = DataSyncVersion.last
        expect(version.record_count).to eq(999)
        expect(version.metadata).to eq({ "note" => "second" })
      end
    end
  end

  describe ".calculate_checksum" do
    let(:file_path) { "spec/fixtures/test_file.json" }
    let(:file_content) { '{"test": "data"}' }

    before do
      FileUtils.mkdir_p(File.dirname(Rails.root.join(file_path)))
      File.write(Rails.root.join(file_path), file_content)
    end

    after do
      File.delete(Rails.root.join(file_path)) if File.exist?(Rails.root.join(file_path))
    end

    it "calculates SHA256 checksum of file" do
      expected_checksum = Digest::SHA256.hexdigest(file_content)
      expect(DataSyncVersion.send(:calculate_checksum, file_path)).to eq(expected_checksum)
    end
  end
end
