# frozen_string_literal: true

class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :external_id                    # From OAuth provider
      t.string :tier, default: 'free', null: false

      # Usage counters (simple, no Redis needed)
      t.integer :weekly_scan_count, default: 0, null: false
      t.date :week_start_date
      t.integer :total_scans_count, default: 0, null: false

      # Downgrade tracking for grace period
      t.date :downgrade_date

      t.jsonb :settings, default: {}
      t.timestamps
    end

    add_index :companies, :slug, unique: true
    add_index :companies, :external_id, unique: true, where: 'external_id IS NOT NULL'
    add_index :companies, :tier
  end
end
