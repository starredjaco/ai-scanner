class AddProbeCountToProbeUploads < ActiveRecord::Migration[8.0]
  def change
    add_column :probe_uploads, :probe_count, :integer

    # Keep the index for sorting and filtering in ActiveAdmin
    # This index is useful for performance when ordering by probe_count or filtering records
    add_index :probe_uploads, :probe_count
  end
end
