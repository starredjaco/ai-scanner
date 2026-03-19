require 'rails_helper'

RSpec.describe "TargetScanAssociation", type: :model do
  let(:company) { create(:company) }

  describe 'association' do
    it "accesses targets through scans" do
      targets = create_list(:target, 2, company: company)
      probes = create_list(:probe, 2)

      scan = Scan.new(name: 'Test Scan', uuid: SecureRandom.uuid, company: company)

      allow(scan).to receive(:update_next_scheduled_run)

      scan.targets = targets
      scan.probes = probes
      scan.save!

      found_targets = Target.joins("INNER JOIN scans_targets ON targets.id = scans_targets.target_id")
                           .where("scans_targets.scan_id = ?", scan.id)

      expect(found_targets.count).to eq(2)
      expect(found_targets.pluck(:id)).to match_array(targets.pluck(:id))

      found_scans = Scan.joins("INNER JOIN scans_targets ON scans.id = scans_targets.scan_id")
                       .where("scans_targets.target_id = ?", targets.first.id)

      expect(found_scans.count).to eq(1)
      expect(found_scans.first.id).to eq(scan.id)
    end
  end
end
