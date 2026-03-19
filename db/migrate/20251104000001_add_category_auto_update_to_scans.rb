class AddCategoryAutoUpdateToScans < ActiveRecord::Migration[8.0]
  def change
    add_column :scans, :auto_update_generic, :boolean, default: false, null: false
    add_column :scans, :auto_update_cm, :boolean, default: false, null: false
    add_column :scans, :auto_update_hp, :boolean, default: false, null: false

    add_index :scans, :auto_update_generic
    add_index :scans, :auto_update_cm
    add_index :scans, :auto_update_hp
  end
end
