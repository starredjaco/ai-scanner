# frozen_string_literal: true

# Adds published status fields to probes for tier-based filtering
#
# The portal distinguishes between:
#   - published: vulnerabilities publicly released to threat feed
#   - disclosed: n-day vulnerabilities (hash-filtered by tier percentage)
#
# Tier visibility = published_probes OR disclosed_probes (union)
#
# Tier limits for published probes:
#   - tier_1: 25 (limited)
#   - tier_2-4: unlimited
class AddPublishedToProbes < ActiveRecord::Migration[8.1]
  def change
    add_column :probes, :published, :boolean, default: false, null: false
    add_column :probes, :published_at, :datetime, null: true

    add_index :probes, [ :enabled, :published ],
              name: "index_probes_on_enabled_and_published"
  end
end
