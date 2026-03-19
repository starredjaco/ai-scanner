class RenameProbeTagToGuid < ActiveRecord::Migration[8.0]
  def change
    rename_column :probes, :tag, :guid
  end
end
