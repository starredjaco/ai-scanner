# frozen_string_literal: true

class ConvertTierToIntegerEnum < ActiveRecord::Migration[8.0]
  def up
    # Add new integer column
    add_column :companies, :tier_int, :integer, default: 0, null: false

    # Map existing string values to integers
    # Old names: free -> 0 (tier_1), small_business -> 1 (tier_2), business -> 2 (tier_3), enterprise -> 3 (tier_4)
    # New names: tier_1 -> 0, tier_2 -> 1, tier_3 -> 2, tier_4 -> 3 (handles backdated migrations)
    execute <<-SQL.squish
      UPDATE companies SET tier_int = CASE tier
        WHEN 'free' THEN 0
        WHEN 'tier_1' THEN 0
        WHEN 'small_business' THEN 1
        WHEN 'tier_2' THEN 1
        WHEN 'business' THEN 2
        WHEN 'tier_3' THEN 2
        WHEN 'enterprise' THEN 3
        WHEN 'tier_4' THEN 3
        ELSE 0
      END
    SQL

    # Remove old string column and rename new integer column
    remove_index :companies, :tier if index_exists?(:companies, :tier)
    remove_column :companies, :tier
    rename_column :companies, :tier_int, :tier

    # Add index for tier queries
    add_index :companies, :tier
  end

  def down
    # Add string column back
    add_column :companies, :tier_str, :string, default: "free", null: false

    # Map integers back to strings
    execute <<-SQL.squish
      UPDATE companies SET tier_str = CASE tier
        WHEN 0 THEN 'free'
        WHEN 1 THEN 'small_business'
        WHEN 2 THEN 'business'
        WHEN 3 THEN 'enterprise'
        ELSE 'free'
      END
    SQL

    # Remove integer column and rename string column back
    remove_index :companies, :tier if index_exists?(:companies, :tier)
    remove_column :companies, :tier
    rename_column :companies, :tier_str, :tier

    # Add index back
    add_index :companies, :tier
  end
end
