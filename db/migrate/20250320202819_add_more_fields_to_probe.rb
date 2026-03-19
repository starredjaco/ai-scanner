class AddMoreFieldsToProbe < ActiveRecord::Migration[8.0]
  def up
    add_column :probes, :summary, :text
    add_column :probes, :disclosure_status, :integer
    add_column :probes, :social_impact_score, :integer
    change_column :probes, :release_date, :date
    change_column :probes, :modified_date, :date

    create_table :techniques do |t|
      t.string :name
      t.string :path
    end

    create_table :probes_techniques, id: false do |t|
      t.references :probe, null: false, foreign_key: true
      t.references :technique, null: false, foreign_key: true
    end

    add_index :probes_techniques, [ :probe_id, :technique_id ], unique: true
  end

  def down
    remove_column :probes, :summary
    remove_column :probes, :disclosure_status
    remove_column :probes, :social_impact_score

    drop_table :probes_techniques
    drop_table :techniques
  end
end
