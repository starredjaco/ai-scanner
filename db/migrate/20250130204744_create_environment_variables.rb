class CreateEnvironmentVariables < ActiveRecord::Migration[8.0]
  def change
    create_table :environment_variables do |t|
      t.integer :target_id, null: true
      t.string :env_name, null: false
      t.string :env_value, null: false

      t.timestamps
    end

    add_index :environment_variables, [ :target_id, :env_name ], unique: true
  end
end
