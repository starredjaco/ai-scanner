# frozen_string_literal: true

class CreateMembershipsAndRefactorUsers < ActiveRecord::Migration[8.0]
  def change
    # 1. Create memberships join table
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.timestamps
    end
    add_index :memberships, [ :user_id, :company_id ], unique: true

    # 2. Add OAuth fields to users
    add_column :users, :external_id, :string
    add_reference :users, :current_company, foreign_key: { to_table: :companies }
    add_index :users, :external_id, unique: true, where: "external_id IS NOT NULL"

    # 3. Migrate existing user-company relationships to memberships
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO memberships (user_id, company_id, created_at, updated_at)
          SELECT id, company_id, NOW(), NOW()
          FROM users
          WHERE company_id IS NOT NULL
          ON CONFLICT DO NOTHING
        SQL

        execute <<-SQL
          UPDATE users SET current_company_id = company_id
          WHERE company_id IS NOT NULL
        SQL
      end
    end

    # 4. Remove company_id from users (moved to memberships)
    remove_foreign_key :users, :companies
    remove_index :users, :company_id
    remove_column :users, :company_id, :bigint
  end
end
