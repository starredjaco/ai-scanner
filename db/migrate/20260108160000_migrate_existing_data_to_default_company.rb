# frozen_string_literal: true

class MigrateExistingDataToDefaultCompany < ActiveRecord::Migration[8.0]
  def up
    default_company = Company.find_or_create_by!(slug: 'default-organization') do |c|
      c.name = 'Default Organization'
    end

    default_company.update!(tier: :tier_4)

    say "Created/found default company: #{default_company.name} (id: #{default_company.id})"

    tables = %w[users targets scans reports output_servers]
    tables.each do |table|
      count = execute("SELECT COUNT(*) FROM #{table} WHERE company_id IS NULL").first['count'].to_i
      if count > 0
        execute("UPDATE #{table} SET company_id = #{default_company.id} WHERE company_id IS NULL")
        say "  Updated #{count} #{table} records"
      else
        say "  No #{table} records to update"
      end
    end
  end

  def down
    default_company = Company.find_by(slug: 'default-organization')
    return unless default_company

    say "Rolling back: setting company_id to NULL for default company records"

    tables = %w[users targets scans reports output_servers]
    tables.each do |table|
      execute("UPDATE #{table} SET company_id = NULL WHERE company_id = #{default_company.id}")
    end
  end
end
