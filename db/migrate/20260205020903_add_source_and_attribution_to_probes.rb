class AddSourceAndAttributionToProbes < ActiveRecord::Migration[8.1]
  def change
    add_column :probes, :source, :string, default: "community", null: false
    add_column :probes, :attribution, :text
    add_index :probes, :source
  end
end
