class AddWebChatFieldsToTargets < ActiveRecord::Migration[8.0]
  def change
    add_column :targets, :target_type, :integer, default: 0, null: false
    add_column :targets, :web_config, :json

    add_index :targets, :target_type
  end
end
