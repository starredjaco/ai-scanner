class AddEnabledToProbes < ActiveRecord::Migration[8.0]
  def change
    add_column :probes, :enabled, :boolean, default: true, null: false
    add_index :probes, :enabled
  end
end
