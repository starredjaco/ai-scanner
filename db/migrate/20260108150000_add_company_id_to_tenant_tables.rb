# frozen_string_literal: true

class AddCompanyIdToTenantTables < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :company, foreign_key: true, index: true, null: true
    add_reference :targets, :company, foreign_key: true, index: true, null: true
    add_reference :scans, :company, foreign_key: true, index: true, null: true
    add_reference :reports, :company, foreign_key: true, index: true, null: true
    add_reference :output_servers, :company, foreign_key: true, index: true, null: true
  end
end
