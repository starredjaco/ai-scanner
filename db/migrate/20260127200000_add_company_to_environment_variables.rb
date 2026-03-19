# frozen_string_literal: true

class AddCompanyToEnvironmentVariables < ActiveRecord::Migration[8.0]
  def up
    add_reference :environment_variables, :company, foreign_key: true

    # Backfill company_id from target's company for target-scoped env vars
    execute <<~SQL
      UPDATE environment_variables
      SET company_id = targets.company_id
      FROM targets
      WHERE environment_variables.target_id = targets.id
        AND environment_variables.company_id IS NULL
    SQL

    # Backfill global env vars (target_id IS NULL) to the first company
    execute <<~SQL
      UPDATE environment_variables
      SET company_id = (SELECT id FROM companies ORDER BY created_at ASC LIMIT 1)
      WHERE environment_variables.target_id IS NULL
        AND environment_variables.company_id IS NULL
        AND EXISTS (SELECT 1 FROM companies)
    SQL

    # Replace uniqueness index to include company_id
    remove_index :environment_variables, [ :target_id, :env_name ]
    add_index :environment_variables, [ :company_id, :target_id, :env_name ],
              unique: true,
              name: "index_env_vars_on_company_target_env_name"

    change_column_null :environment_variables, :company_id, false
  end

  def down
    remove_index :environment_variables, name: "index_env_vars_on_company_target_env_name"
    add_index :environment_variables, [ :target_id, :env_name ], unique: true

    change_column_null :environment_variables, :company_id, true
    remove_reference :environment_variables, :company, foreign_key: true
  end
end
