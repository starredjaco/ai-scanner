class AddDeletedAtToDetectors < ActiveRecord::Migration[8.0]
  def change
    add_column :detectors, :deleted_at, :datetime
    add_index :detectors, :deleted_at
  end
end
