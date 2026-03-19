class CreateTaxonomyCategories < ActiveRecord::Migration[8.0]
  def up
    create_table :taxonomy_categories do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :taxonomy_categories, :name, unique: true

    create_table :probes_taxonomy_categories, id: false do |t|
      t.references :probe, null: false, foreign_key: true
      t.references :taxonomy_category, null: false, foreign_key: true
    end
    add_index :probes_taxonomy_categories, [ :probe_id, :taxonomy_category_id ], unique: true, name: 'index_probes_taxonomy_categories_unique'
  end

  def down
    drop_table :probes_taxonomy_categories
    remove_index :taxonomy_categories, :name
    drop_table :taxonomy_categories
  end
end
