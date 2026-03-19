FactoryBot.define do
  factory :data_sync_version do
    sync_type { "probes" }
    file_path { "config/probes/community_probes.json" }
    file_checksum { SecureRandom.hex(32) }
    record_count { 100 }
    synced_at { Time.current }
    metadata { { "disabled_count" => 0, "enabled_count" => 0 } }
  end
end
