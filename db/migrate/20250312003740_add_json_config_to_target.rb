class AddJsonConfigToTarget < ActiveRecord::Migration[8.0]
  def change
    add_column :targets, :json_config, :jsonb
  end
end
