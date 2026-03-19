# frozen_string_literal: true

# Extends the published probes index to include published_at for sort optimization
#
# Query pattern in ProbeAccess#fetch_published_ids:
#   SELECT id FROM probes
#   WHERE enabled = true AND published = true
#   ORDER BY published_at DESC
#   LIMIT 25
#
# This composite index allows:
#   1. Index lookup for WHERE (enabled, published)
#   2. Index-ordered scan for ORDER BY (published_at DESC)
#   3. Avoids in-memory sort operation
#
# Replaces: index_probes_on_enabled_and_published
class AddPublishedAtToProbeIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Remove old index
    remove_index :probes, name: "index_probes_on_enabled_and_published", algorithm: :concurrently, if_exists: true

    # Add new composite index with published_at for sort optimization
    add_index :probes,
              [ :enabled, :published, :published_at ],
              name: "index_probes_on_published_filtering",
              algorithm: :concurrently
  end
end
