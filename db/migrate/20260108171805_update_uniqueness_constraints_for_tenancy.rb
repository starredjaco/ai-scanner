# frozen_string_literal: true

class UpdateUniquenessConstraintsForTenancy < ActiveRecord::Migration[8.0]
  def up
    # Safety check: Ensure no NULL company_ids exist before adding NOT NULL constraints
    %w[users targets scans reports output_servers].each do |table|
      count = execute("SELECT COUNT(*) FROM #{table} WHERE company_id IS NULL").first["count"].to_i
      if count > 0
        raise "Cannot proceed: #{count} records in #{table} have NULL company_id. Run data migration first."
      end
    end

    # Remove old global unique indexes
    remove_index :targets, :name, if_exists: true
    remove_index :output_servers, :name, if_exists: true

    # Add compound unique indexes (scoped by tenant)
    add_index :targets, [ :company_id, :name ], unique: true,
              name: "index_targets_on_company_id_and_name"
    add_index :output_servers, [ :company_id, :name ], unique: true,
              name: "index_output_servers_on_company_id_and_name"

    # Make company_id NOT NULL on all tenant tables
    change_column_null :users, :company_id, false
    change_column_null :targets, :company_id, false
    change_column_null :scans, :company_id, false
    change_column_null :reports, :company_id, false
    change_column_null :output_servers, :company_id, false
  end

  def down
    # Make company_id nullable again
    change_column_null :output_servers, :company_id, true
    change_column_null :reports, :company_id, true
    change_column_null :scans, :company_id, true
    change_column_null :targets, :company_id, true
    change_column_null :users, :company_id, true

    # Remove compound indexes
    remove_index :output_servers, [ :company_id, :name ], if_exists: true
    remove_index :targets, [ :company_id, :name ], if_exists: true

    # Restore global unique indexes
    add_index :output_servers, :name, unique: true
    add_index :targets, :name, unique: true
  end
end
