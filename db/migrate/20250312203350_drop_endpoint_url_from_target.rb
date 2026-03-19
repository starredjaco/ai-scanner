class DropEndpointUrlFromTarget < ActiveRecord::Migration[8.0]
  def up
    remove_column :targets, :endpoint_url, :string
  end

  def down
    add_column :targets, :endpoint_url, :string
  end
end
