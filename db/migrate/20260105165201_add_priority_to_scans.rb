class AddPriorityToScans < ActiveRecord::Migration[8.1]
  def change
    add_column :scans, :priority, :boolean, default: false, null: false
  end
end
