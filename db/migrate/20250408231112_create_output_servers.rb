class CreateOutputServers < ActiveRecord::Migration[8.0]
  def change
    create_table :output_servers do |t|
      t.string :name, null: false
      t.integer :server_type, null: false
      t.string :host, null: false
      t.integer :port
      t.integer :protocol, null: false, default: 0
      t.string :endpoint_path
      t.string :access_token
      t.string :api_key
      t.string :username
      t.string :password
      t.json :additional_settings
      t.boolean :enabled, default: true
      t.text :description
      t.timestamps
    end

    add_index :output_servers, :name, unique: true
    add_index :output_servers, :server_type
    add_index :output_servers, :enabled
  end
end
