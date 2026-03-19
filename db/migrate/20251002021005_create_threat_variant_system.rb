class CreateThreatVariantSystem < ActiveRecord::Migration[8.0]
  def up
    # Create threat_variant_industries table
    create_table :threat_variant_industries do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :threat_variant_industries, :name, unique: true

    # Create threat_variant_subindustries table
    create_table :threat_variant_subindustries do |t|
      t.references :threat_variant_industry, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :threat_variant_subindustries, [ :threat_variant_industry_id, :name ],
              unique: true, name: 'index_tv_subindustries_on_industry_and_name'
    add_index :threat_variant_subindustries, :name

    # Create threat_variants table (storing variant class names in prompt field)
    create_table :threat_variants do |t|
      t.references :probe, null: false, foreign_key: true
      t.references :threat_variant_subindustry, null: false, foreign_key: true
      t.text :prompt # Stores the variant class name
      t.text :key_changes
      t.text :rationale
      t.integer :position
      t.timestamps
    end
    add_index :threat_variants, [ :probe_id, :threat_variant_subindustry_id ],
              name: 'index_tv_on_probe_and_subindustry'

    # Create join table for scans and threat_variant_subindustries
    create_table :scans_threat_variant_subindustries do |t|
      t.references :scan, null: false, foreign_key: true
      t.references :threat_variant_subindustry, null: false, foreign_key: true
      t.timestamps
    end
    add_index :scans_threat_variant_subindustries, [ :scan_id, :threat_variant_subindustry_id ],
              unique: true, name: 'index_scan_variant_subindustries'

    # Add parent-child relationship for variant reports
    add_reference :reports, :parent_report, foreign_key: { to_table: :reports }, index: true

    # Create join table for reports and variant probes (multiple probes per child report)
    # Note: Using id: true (with timestamps) for has_many :through association pattern
    create_table :report_variant_probes do |t|
      t.references :report, null: false, foreign_key: true, index: false
      t.references :probe, null: false, foreign_key: true, index: false
      t.timestamps
    end
    add_index :report_variant_probes, [ :report_id, :probe_id ], unique: true
    add_index :report_variant_probes, :probe_id

    # Add variant reference to probe_results
    add_reference :probe_results, :threat_variant, null: true, foreign_key: true, index: true

    # Update unique index on probe_results to include threat_variant_id
    remove_index :probe_results, name: "index_probe_results_on_report_id_and_probe_id"
    add_index :probe_results,
              [ :report_id, :probe_id, :threat_variant_id ],
              unique: true,
              name: "index_probe_results_on_report_probe_variant"

    # Note: Data import moved to rake task. Run `rails threat_variants:import` after migration.
  end

  def down
    # Drop tables in reverse order (with existence checks for safety)
    drop_table :report_variant_probes if table_exists?(:report_variant_probes)
    remove_reference :reports, :parent_report, foreign_key: { to_table: :reports }, index: true if column_exists?(:reports, :parent_report_id)
    drop_table :scans_threat_variant_subindustries if table_exists?(:scans_threat_variant_subindustries)
    drop_table :threat_variants if table_exists?(:threat_variants)
    drop_table :threat_variant_subindustries if table_exists?(:threat_variant_subindustries)
    drop_table :threat_variant_industries if table_exists?(:threat_variant_industries)

    # Revert probe_results changes
    if index_exists?(:probe_results, [ :report_id, :probe_id, :threat_variant_id ], name: "index_probe_results_on_report_probe_variant")
      remove_index :probe_results, name: "index_probe_results_on_report_probe_variant"
    end
    unless index_exists?(:probe_results, [ :report_id, :probe_id ], name: "index_probe_results_on_report_id_and_probe_id")
      add_index :probe_results, [ :report_id, :probe_id ],
                unique: true, name: "index_probe_results_on_report_id_and_probe_id"
    end
    remove_reference :probe_results, :threat_variant, foreign_key: true, index: true if column_exists?(:probe_results, :threat_variant_id)
  end
end
