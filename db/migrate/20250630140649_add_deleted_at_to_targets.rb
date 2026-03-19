class AddDeletedAtToTargets < ActiveRecord::Migration[8.0]
  def change
    add_column :targets, :deleted_at, :datetime
    add_index :targets, :deleted_at
  end
end
